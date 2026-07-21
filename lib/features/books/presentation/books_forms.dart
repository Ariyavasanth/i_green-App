import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visual_effects.dart';
import '../domain/books_repository.dart';
import '../invoice_voice/domain/invoice_voice_parameters.dart';
import '../invoice_voice/providers/invoice_voice_providers.dart';
import '../providers/books_providers.dart';
import 'widgets/sales_order_form.dart';

class NewItemPage extends ConsumerStatefulWidget {
  const NewItemPage({super.key});
  @override
  ConsumerState<NewItemPage> createState() => _NewItemState();
}

class _NewItemState extends ConsumerState<NewItemPage> {
  final name = TextEditingController(),
      sku = TextEditingController(),
      rate = TextEditingController(),
      hsnCode = TextEditingController(),
      salesDescription = TextEditingController(),
      costPrice = TextEditingController(),
      purchaseDescription = TextEditingController();
  bool saving = false;
  bool trackInventory = false;
  String itemType = 'Goods';
  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    rate.dispose();
    hsnCode.dispose();
    salesDescription.dispose();
    costPrice.dispose();
    purchaseDescription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'New Item',
    saving: saving,
    onSave: save,
    maxWidth: 1120,
    children: [
      const SectionTitle('Basic Information'),
      LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(name, 'Name*'),
              const SizedBox(height: 14),
              const Text('Type'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Goods', label: Text('Goods')),
                  ButtonSegment(value: 'Service', label: Text('Service')),
                ],
                selected: {itemType},
                onSelectionChanged: (values) =>
                    setState(() => itemType = values.first),
              ),
              const SizedBox(height: 14),
              field(sku, 'SKU'),
              const SizedBox(height: 14),
              const StaticSelect('Unit', 'pcs'),
              const SizedBox(height: 14),
              field(hsnCode, 'HSN Code'),
              const SizedBox(height: 14),
              const StaticSelect('Tax Preference*', 'Taxable'),
            ],
          );
          // The reference moves the image beside basic fields on wide screens.
          if (constraints.maxWidth < AppBreakpoints.laptop) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 18),
                const ItemImageUpload(),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: details),
              const SizedBox(width: 32),
              const Expanded(flex: 2, child: ItemImageUpload()),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      LayoutBuilder(
        builder: (context, constraints) {
          final sales = _ItemInfoSection(
            title: 'Sales Information',
            children: [
              field(rate, 'Selling Price*', prefix: 'INR', number: true),
              const SizedBox(height: 14),
              field(salesDescription, 'Description', lines: 3),
              const SizedBox(height: 14),
              const StaticSelect('Account*', 'Sales'),
            ],
          );
          final purchase = _ItemInfoSection(
            title: 'Purchase Information',
            children: [
              field(costPrice, 'Cost Price', prefix: 'INR', number: true),
              const SizedBox(height: 14),
              field(purchaseDescription, 'Description', lines: 3),
              const SizedBox(height: 14),
              const StaticSelect('Account*', 'Cost of Goods Sold'),
              const SizedBox(height: 14),
              const StaticSelect('Preferred Vendor', 'Select a vendor'),
            ],
          );
          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [sales, const SizedBox(height: 28), purchase],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sales),
              const SizedBox(width: 28),
              Expanded(child: purchase),
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      const SectionTitle('Default Tax Rates'),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Intra State Tax Rate'),
        trailing: Text('GST18 (18 %)'),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Inter State Tax Rate'),
        trailing: Text('IGST18 (18 %)'),
      ),
      const SizedBox(height: 18),
      const SectionTitle('Inventory'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: trackInventory,
        onChanged: (value) => setState(() => trackInventory = value ?? false),
        title: const Text('Track Inventory for this item'),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'You cannot enable/disable inventory tracking once you\'ve created transactions for this item.',
          ),
        ),
      ),
    ],
  );
  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addItem(
          name: name.text.trim(),
          sku: sku.text.trim(),
          rate: double.tryParse(rate.text) ?? 0,
          type: itemType,
        );
    ref.invalidate(itemsProvider);
    if (mounted) context.pop();
  }
}

class NewTransactionPage extends ConsumerStatefulWidget {
  const NewTransactionPage({required this.type, super.key});
  final TransactionType type;
  @override
  ConsumerState<NewTransactionPage> createState() => _NewTransactionState();
}

class _NewTransactionState extends ConsumerState<NewTransactionPage> {
  final customer = TextEditingController(),
      number = TextEditingController(),
      item = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      rate = TextEditingController(text: '0'),
      notes = TextEditingController(),
      terms = TextEditingController();
  final orderNumber = TextEditingController(),
      discount = TextEditingController(text: '0'),
      advance = TextEditingController(text: '0');
  final List<_InvoiceItemInput> invoiceItems = [_InvoiceItemInput()];
  final List<PlatformFile> attachments = [];
  DateTime invoiceDate = DateTime.now();
  DateTime? dueDate;
  String paymentTerms = 'Due on Receipt';
  String discountType = '%';
  String tax = 'No Tax';
  String withholdingType = 'TDS';
  bool saving = false;
  _InvoiceVoiceStatus voiceStatus = _InvoiceVoiceStatus.ready;
  String voiceMessage = 'Start with “Hey Nova”';
  bool _wakePhraseDetected = false;
  bool _voiceFinishing = false;
  bool _voiceSessionActive = false;
  bool _voiceRestarting = false;
  String _voiceTranscript = '';
  int _liveVoiceParseGeneration = 0;
  String get label => switch (widget.type) {
    TransactionType.quote => 'Quote',
    TransactionType.salesOrder => 'Sales Order',
    TransactionType.invoice => 'Invoice',
  };
  @override
  void initState() {
    super.initState();
    number.text = widget.type == TransactionType.quote
        ? 'IGT-EST-1252'
        : widget.type == TransactionType.salesOrder
        ? 'IGT PI1451'
        : 'IGT-1113';
  }

  @override
  void dispose() {
    ref.read(invoiceRealtimeVoiceClientProvider).stop();
    for (final controller in [customer, number, item, quantity, rate, notes, terms, orderNumber, discount, advance]) {
      controller.dispose();
    }
    for (final row in invoiceItems) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sales Order gets a fully redesigned creation experience on every
    // width (see SalesOrderForm); the other transaction types keep the
    // existing flat form, on every width, unchanged.
    if (widget.type == TransactionType.salesOrder) {
      return const SalesOrderForm();
    }
    if (widget.type == TransactionType.invoice) {
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < AppBreakpoints.tablet
            ? _buildMobileInvoice(context)
            : _buildLegacy(context),
      );
    }
    return _buildLegacy(context);
  }

  Widget _buildMobileInvoice(BuildContext context) {
    final subtotal = invoiceItems.fold<double>(0, (sum, row) => sum + row.total);
    final discountValue = double.tryParse(discount.text) ?? 0;
    final calculatedDiscount = discountType == '%' ? subtotal * discountValue / 100 : discountValue;
    final grandTotal = (subtotal - calculatedDiscount - (double.tryParse(advance.text) ?? 0))
        .clamp(0, double.infinity)
        .toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('New Invoice')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
        children: [
          _InvoiceVoiceControl(
            status: voiceStatus,
            message: voiceMessage,
            onStart: voiceStatus.isBusy ? null : _startInvoiceVoice,
            onCancel: voiceStatus.isBusy ? _cancelInvoiceVoice : null,
          ),
          const SizedBox(height: 14),
          _InvoiceFormCard(
            title: 'Customer Information',
            icon: Icons.person_outline,
            child: Column(children: [
              field(customer, 'Customer Name *'),
              const SizedBox(height: 12),
              field(number, 'Invoice Number *'),
              const SizedBox(height: 12),
              field(orderNumber, 'Order Number'),
              const SizedBox(height: 12),
              _dateField('Invoice Date *', invoiceDate, (value) => setState(() => invoiceDate = value)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(paymentTerms),
                initialValue: paymentTerms,
                decoration: const InputDecoration(labelText: 'Payment Terms'),
                items: const ['Due on Receipt', 'Net 15', 'Net 30', 'Net 45', 'Net 60'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (value) => setState(() {
                  paymentTerms = value ?? paymentTerms;
                  final days = int.tryParse(paymentTerms.split(' ').last) ?? 0;
                  dueDate = invoiceDate.add(Duration(days: days));
                }),
              ),
              const SizedBox(height: 12),
              _dateField('Due Date', dueDate, (value) => setState(() => dueDate = value)),
              const SizedBox(height: 12),
              const StaticSelect('Salesperson', 'Anwar'),
            ]),
          ),
          const SizedBox(height: 14),
          _InvoiceFormCard(
            title: 'Items',
            icon: Icons.inventory_2_outlined,
            child: Column(children: [
              for (var i = 0; i < invoiceItems.length; i++) ...[
                _InvoiceItemCard(
                  index: i,
                  item: invoiceItems[i],
                  canRemove: invoiceItems.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => invoiceItems.removeAt(i).dispose()),
                  onDuplicate: () => setState(() => invoiceItems.insert(i + 1, invoiceItems[i].copy())),
                ),
                if (i != invoiceItems.length - 1) const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => setState(() => invoiceItems.add(_InvoiceItemInput())),
                icon: const Icon(Icons.add), label: const Text('Add Item'),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          _InvoiceFormCard(
            title: 'Invoice Summary',
            icon: Icons.calculate_outlined,
            child: Column(children: [
              _compactSummaryRow('Sub Total', subtotal),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(flex: 2, child: field(discount, 'Discount', number: true, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(
                  key: ValueKey(discountType),
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const ['%', 'Amount'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => discountType = v ?? discountType),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _withholdingChoice('TDS'),
                _withholdingChoice('TCS'),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(tax),
                    initialValue: tax,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, hintText: 'Select a Tax'),
                    items: const ['No Tax', 'GST 5%', 'GST 12%', 'GST 18%', 'GST 28%']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => tax = v ?? tax),
                  ),
                ),
              ]),
              field(advance, 'Advance Received', prefix: '₹', number: true, onChanged: (_) => setState(() {})),
              const Divider(height: 28),
              _compactSummaryRow('Total (₹)', grandTotal, strong: true),
            ]),
          ),
          const SizedBox(height: 14),
          _InvoiceFormCard(title: 'Customer Notes', icon: Icons.notes_outlined, child: field(notes, 'Notes', lines: 4)),
          const SizedBox(height: 14),
          _InvoiceFormCard(title: 'Terms & Conditions', icon: Icons.gavel_outlined, child: field(terms, 'Invoice terms', lines: 4)),
          const SizedBox(height: 14),
          _InvoiceFormCard(title: 'Attachments', icon: Icons.attach_file, child: Column(children: [
            for (var i = 0; i < attachments.length; i++) ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(attachments[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${(attachments[i].size / 1024).toStringAsFixed(1)} KB'),
              trailing: IconButton(tooltip: 'Remove attachment', onPressed: () => setState(() => attachments.removeAt(i)), icon: const Icon(Icons.close)),
            ),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _pickAttachments, icon: const Icon(Icons.upload_file), label: const Text('Upload Files'))),
            const SizedBox(height: 8),
            const Text('Maximum 5 files, up to 10 MB each', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            IconButton(tooltip: 'Cancel', onPressed: saving ? null : () => context.pop(), icon: const Icon(Icons.close)),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: saving ? null : () => save(grandTotal), child: const Text('Save as Draft'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: saving ? null : () => save(grandTotal), child: Text(saving ? 'Saving...' : 'Save & Send'))),
          ]),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) => TextFormField(
    key: ValueKey('$label-${value?.millisecondsSinceEpoch ?? 'empty'}'),
    readOnly: true,
    initialValue: value == null ? '' : DateFormat('dd/MM/yyyy').format(value),
    decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
    onTap: () async {
      final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (picked != null) onPicked(picked);
    },
  );

  Widget _amountRow(String label, double value, {bool strong = false}) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500, fontSize: strong ? 17 : 14))),
    Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w600, fontSize: strong ? 18 : 14)),
  ]);

  Widget _compactSummaryRow(String label, double value, {bool strong = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: strong ? 15 : 13,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        value.toStringAsFixed(2),
        style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w600),
      ),
    ],
  );

  Widget _withholdingChoice(String value) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => setState(() => withholdingType = value),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            withholdingType == value ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 17,
            color: withholdingType == value ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    ),
  );

  Future<void> _startInvoiceVoice() async {
    setState(() {
      voiceStatus = _InvoiceVoiceStatus.waiting;
      voiceMessage = 'Connecting to Nova…';
      _voiceSessionActive = true;
      _voiceTranscript = '';
    });
    try {
      await ref.read(invoiceRealtimeVoiceClientProvider).start(
        onTranscript: (transcript, isFinal) {
          if (!mounted || !_voiceSessionActive) return;
          _voiceTranscript = transcript;
          // Keep the instant local path while Realtime semantically resolves mixed-language fields.
          _applyImmediateVoiceFields(transcript);
          setState(() {
            voiceStatus = _InvoiceVoiceStatus.listening;
            voiceMessage = transcript;
          });
        },
        onValues: (values) {
          if (!mounted || !_voiceSessionActive) return;
          _applyVoiceParameters(values);
          setState(() {
            voiceStatus = _InvoiceVoiceStatus.listening;
            voiceMessage = 'Invoice values updated — keep speaking naturally';
          });
        },
        onFinished: () {
          if (!mounted || !_voiceSessionActive) return;
          setState(() {
            voiceStatus = _InvoiceVoiceStatus.waiting;
            voiceMessage = 'Say “Hey Nova”';
            _voiceTranscript = '';
          });
        },
        onStatus: (status) {
          if (!mounted || !_voiceSessionActive) return;
          setState(() {
            voiceStatus = status.startsWith('Say') ? _InvoiceVoiceStatus.waiting : _InvoiceVoiceStatus.listening;
            voiceMessage = status;
          });
        },
        onError: (message) {
          if (!mounted) return;
          setState(() {
            voiceStatus = _InvoiceVoiceStatus.error;
            voiceMessage = message;
          });
        },
      );
    } catch (_) {
      _voiceSessionActive = false;
      if (mounted && voiceStatus != _InvoiceVoiceStatus.error) {
        setState(() { voiceStatus = _InvoiceVoiceStatus.error; voiceMessage = 'Could not connect to Nova Realtime'; });
      }
    }
  }

  void _applyImmediateVoiceFields(String transcript) {
    // Common field phrases are filled locally so the form reacts before the AI request finishes.
    final fieldStarts = r'invoice(?:\s+number)?|order(?:\s+(?:name|number))?|item|quantity|rate|payment|due|discount|advance|notes?|terms?';
    final customerMatch = RegExp(
      'customer(?:\\s+name)?(?:\\s+(?:is|as))?\\s+(.+?)(?=\\s+(?:$fieldStarts)\\b|\$)',
      caseSensitive: false,
    ).firstMatch(transcript);
    final orderMatch = RegExp(
      'order(?:\\s+(?:name|number))?(?:\\s+(?:is|as))?\\s+(.+?)(?=\\s+(?:customer|invoice|item|quantity|rate|payment|due|discount|advance|notes?|terms?)\\b|\$)',
      caseSensitive: false,
    ).firstMatch(transcript);
    final invoiceMatch = RegExp(
      'invoice\\s+number(?:\\s+(?:is|as))?\\s+([A-Za-z0-9-]+)',
      caseSensitive: false,
    ).firstMatch(transcript);
    if (customerMatch != null) customer.text = customerMatch.group(1)!.trim();
    if (orderMatch != null) orderNumber.text = orderMatch.group(1)!.trim();
    if (invoiceMatch != null) number.text = invoiceMatch.group(1)!.trim();
    final spokenInvoiceDate = _extractSpokenDate(transcript, 'invoice');
    final spokenDueDate = _extractSpokenDate(transcript, 'due');
    if (spokenInvoiceDate != null) invoiceDate = spokenInvoiceDate;
    if (spokenDueDate != null) dueDate = spokenDueDate;
  }

  DateTime? _extractSpokenDate(String transcript, String label) {
    final spoken = RegExp(
      '$label\\s+(?:date|dat|day)(?:\\s+(?:is|as|on))?\\s+([\\d\\s/.-]{6,16})',
      caseSensitive: false,
    ).firstMatch(transcript);
    if (spoken == null) return null;
    // Device recognition often removes separators, so normalize to ddMMyyyy first.
    final digits = spoken.group(1)!.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    final dateDigits = digits.substring(0, 8);
    return _validVoiceDate(
      int.parse(dateDigits.substring(0, 2)),
      int.parse(dateDigits.substring(2, 4)),
      int.parse(dateDigits.substring(4, 8)),
    );
  }

  DateTime? _validVoiceDate(int day, int month, int year) {
    final value = DateTime(year, month, day);
    // Reject rollover values such as 31/02 instead of silently changing the date.
    return value.year == year && value.month == month && value.day == day ? value : null;
  }

  String? _commandAfterWakePhrase(String transcript) {
    // Device engines commonly render Nova as Noah, Noba, or two words ("No Va").
    final match = RegExp(
      r'(?:hey|hai|hi|hey\s+there)\s+(?:nova|novaa|noba|noah|no\s+va)|ஹே\s*நோவா',
      caseSensitive: false,
    ).firstMatch(transcript);
    if (match == null) return _wakePhraseDetected ? transcript.trim() : null;
    return transcript.substring(match.end).trim();
  }

  bool _hasCompletionPhrase(String value) => RegExp(
    r'(finished|done|complete|that.?s all|avlothan|avlo than|podhum|mudichiten|mudinjiduchu|sari avlothan)\s*[.!?]*$',
    caseSensitive: false,
  ).hasMatch(value.trim());

  String _removeCompletionPhrase(String value) => value.replaceFirst(
    RegExp(r'[,\s]*(finished|done|complete|that.?s all|avlothan|avlo than|podhum|mudichiten|mudinjiduchu|sari avlothan)\s*[.!?]*$', caseSensitive: false),
    '',
  ).trim();

  Future<void> _cancelInvoiceVoice() async {
    _voiceSessionActive = false;
    await ref.read(invoiceRealtimeVoiceClientProvider).stop();
    if (mounted) setState(() { voiceStatus = _InvoiceVoiceStatus.ready; voiceMessage = 'Start with “Hey Nova”'; });
  }

  void _applyVoiceParameters(InvoiceVoiceParameters values) {
    // Apply only non-null AI values so existing manual entries remain untouched.
    setState(() {
      if (values.customerName != null) customer.text = values.customerName!;
      if (values.invoiceNumber != null) number.text = values.invoiceNumber!;
      if (values.orderNumber != null) orderNumber.text = values.orderNumber!;
      if (values.invoiceDate != null) invoiceDate = values.invoiceDate!;
      if (values.paymentTerms != null) paymentTerms = values.paymentTerms!;
      if (values.dueDate != null) dueDate = values.dueDate!;
      if (values.discount != null) discount.text = _voiceNumber(values.discount!);
      if (values.discountType != null) discountType = values.discountType!;
      if (values.taxMode != null) withholdingType = values.taxMode!;
      if (values.invoiceTax != null) tax = values.invoiceTax!;
      if (values.advanceReceived != null) advance.text = _voiceNumber(values.advanceReceived!);
      if (values.notes != null) notes.text = values.notes!;
      if (values.termsAndConditions != null) terms.text = values.termsAndConditions!;
      // Explicit "another/new item" commands append instead of overwriting row zero.
      final itemOffset = values.appendItems ? invoiceItems.length : 0;
      while (invoiceItems.length < itemOffset + values.items.length) invoiceItems.add(_InvoiceItemInput());
      for (var i = 0; i < values.items.length; i++) {
        final source = values.items[i];
        final target = invoiceItems[itemOffset + i];
        if (source.name != null) target.name.text = source.name!;
        if (source.description != null) target.description.text = source.description!;
        if (source.quantity != null) target.quantity.text = _voiceNumber(source.quantity!);
        if (source.rate != null) target.rate.text = _voiceNumber(source.rate!);
        if (source.tax != null) target.tax = source.tax!;
      }
      // Voice duplication follows the form's existing "Duplicate" action.
      if (values.duplicateItem && invoiceItems.isNotEmpty) {
        invoiceItems.add(invoiceItems.last.copy());
      }
    });
  }

  String _voiceNumber(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: false);
    if (result == null || !mounted) return;
    // Attachments remain local because the current transaction API has no upload contract.
    setState(() => attachments.addAll(result.files.where((f) => f.size <= 10 * 1024 * 1024).take(5 - attachments.length)));
  }

  Widget _buildLegacy(BuildContext context) {
    final total =
        (double.tryParse(quantity.text) ?? 0) *
        (double.tryParse(rate.text) ?? 0);
    return FormPage(
      title: 'New $label',
      saving: saving,
      onSave: () => save(total),
      children: [
        field(customer, 'Customer Name*'),
        const SizedBox(height: 14),
        field(number, '$label#*'),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: DateFormat('dd/MM/yyyy').format(DateTime.now()),
          readOnly: true,
          decoration: InputDecoration(labelText: '$label Date*'),
        ),
        const SizedBox(height: 14),
        const StaticSelect('Salesperson', 'Anwar'),
        const SizedBox(height: 24),
        const SectionTitle('Item Table'),
        field(item, 'Item details'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final quantityField = field(
              quantity,
              'Quantity',
              number: true,
              onChanged: (_) => setState(() {}),
            );
            final rateField = field(
              rate,
              'Rate',
              number: true,
              onChanged: (_) => setState(() {}),
            );
            // Keep fields full-width on small phones and pair them when readable.
            if (constraints.maxWidth < 420) {
              return Column(
                children: [
                  quantityField,
                  const SizedBox(height: 12),
                  rateField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: quantityField),
                const SizedBox(width: 12),
                Expanded(child: rateField),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sub Total'),
          trailing: Text('₹${total.toStringAsFixed(2)}'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Total (₹)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Text(
            '₹${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 20),
        field(notes, 'Customer Notes', lines: 3),
        const SizedBox(height: 14),
        field(terms, 'Terms & Conditions', lines: 4),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.upload_file),
          label: Text('Attach File(s) to $label'),
        ),
      ],
    );
  }

  Future<void> save(double total) async {
    if (customer.text.trim().isEmpty || number.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name and invoice number are required.')),
      );
      return;
    }
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            type: widget.type,
            customer: customer.text.trim(),
            number: number.text.trim(),
            date: widget.type == TransactionType.invoice ? invoiceDate : DateTime.now(),
            amount: total,
            dueDate: widget.type == TransactionType.invoice ? dueDate : null,
            referenceNumber: widget.type == TransactionType.invoice ? orderNumber.text.trim() : '',
            discount: widget.type == TransactionType.invoice
                ? (double.tryParse(discount.text) ?? 0)
                : 0,
            amountPaid: widget.type == TransactionType.invoice
                ? (double.tryParse(advance.text) ?? 0)
                : 0,
            notes: notes.text.trim(),
            terms: terms.text.trim(),
            paymentTerms: widget.type == TransactionType.invoice ? paymentTerms : '',
            discountType: widget.type == TransactionType.invoice ? discountType : '%',
            items: widget.type == TransactionType.invoice
                ? invoiceItems
                    .where((row) => row.name.text.trim().isNotEmpty)
                    .map((row) => InvoiceLineDraft(name: row.name.text.trim(), description: row.description.text.trim(), quantity: double.tryParse(row.quantity.text) ?? 0, rate: double.tryParse(row.rate.text) ?? 0, tax: row.tax))
                    .toList()
                : const [],
          ),
        );
    ref.invalidate(transactionsProvider(widget.type));
    if (mounted) context.pop();
  }
}

class FormPage extends StatelessWidget {
  const FormPage({
    required this.title,
    required this.children,
    required this.onSave,
    required this.saving,
    this.maxWidth = AppLayout.maxFormWidth,
    this.saveLabel = 'Save as Draft',
    this.showLeading = true,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final double maxWidth;
  final String saveLabel;
  final bool showLeading;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.canvas, AppColors.canvas],
      ),
    ),
    child: Column(
      children: [
        AppBar(automaticallyImplyLeading: showLeading, title: Text(title)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = AppLayout.gutter(constraints.maxWidth);
              return FadeSlideIn(
                child: ResponsiveContent(
                  maxWidth: maxWidth,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
                    children: [
                      GlassPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final save = ElevatedButton(
                  onPressed: saving ? null : onSave,
                  child: Text(saving ? 'Saving...' : saveLabel),
                );
                final cancel = OutlinedButton(
                  onPressed: saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                );
                if (constraints.maxWidth < 380) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [save, const SizedBox(height: 8), cancel],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: save),
                    const SizedBox(width: 10),
                    cancel,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _InvoiceItemInput {
  _InvoiceItemInput({String name = '', String description = '', String quantity = '1', String rate = '0', this.tax = 'No Tax'})
      : name = TextEditingController(text: name),
        description = TextEditingController(text: description),
        quantity = TextEditingController(text: quantity),
        rate = TextEditingController(text: rate);
  final TextEditingController name, description, quantity, rate;
  String tax;
  double get total => (double.tryParse(quantity.text) ?? 0) * (double.tryParse(rate.text) ?? 0);
  _InvoiceItemInput copy() => _InvoiceItemInput(name: name.text, description: description.text, quantity: quantity.text, rate: rate.text, tax: tax);
  void dispose() { name.dispose(); description.dispose(); quantity.dispose(); rate.dispose(); }
}

enum _InvoiceVoiceStatus { ready, waiting, listening, processing, success, error }

extension on _InvoiceVoiceStatus {
  bool get isBusy => this == _InvoiceVoiceStatus.waiting || this == _InvoiceVoiceStatus.listening || this == _InvoiceVoiceStatus.processing;
}

class _InvoiceVoiceControl extends StatelessWidget {
  const _InvoiceVoiceControl({required this.status, required this.message, required this.onStart, required this.onCancel});
  final _InvoiceVoiceStatus status;
  final String message;
  final VoidCallback? onStart, onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        IconButton.filledTonal(
          tooltip: 'Fill invoice by voice',
          onPressed: onStart,
          icon: Icon(status == _InvoiceVoiceStatus.processing ? Icons.hourglass_top : Icons.mic_none),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Voice', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        if (onCancel != null) TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ]),
    ),
  );
}

class _InvoiceFormCard extends StatelessWidget {
  const _InvoiceFormCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    ),
  );
}

class _InvoiceItemCard extends StatefulWidget {
  const _InvoiceItemCard({required this.index, required this.item, required this.canRemove, required this.onChanged, required this.onRemove, required this.onDuplicate});
  final int index;
  final _InvoiceItemInput item;
  final bool canRemove;
  final VoidCallback onChanged, onRemove, onDuplicate;
  @override State<_InvoiceItemCard> createState() => _InvoiceItemCardState();
}

class _InvoiceItemCardState extends State<_InvoiceItemCard> {
  bool expanded = true;
  @override Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 180),
    child: DecoratedBox(
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => expanded = !expanded),
          child: SizedBox(height: 52, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            Expanded(child: Text(widget.item.name.text.trim().isEmpty ? 'Item ${widget.index + 1}' : widget.item.name.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('₹${widget.item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ]))),
        ),
        if (expanded) Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [
            field(widget.item.name, 'Item Selector', onChanged: (_) => widget.onChanged()),
            const SizedBox(height: 10),
            field(widget.item.description, 'Description', lines: 2),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: field(widget.item.quantity, 'Quantity', number: true, onChanged: (_) => widget.onChanged())),
              const SizedBox(width: 10),
              Expanded(child: field(widget.item.rate, 'Rate', prefix: '₹', number: true, onChanged: (_) => widget.onChanged())),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(widget.item.tax),
              initialValue: widget.item.tax,
              decoration: const InputDecoration(labelText: 'Tax Selection'),
              items: const ['No Tax', 'GST 5%', 'GST 12%', 'GST 18%', 'GST 28%'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) { widget.item.tax = v ?? widget.item.tax; widget.onChanged(); },
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(onPressed: widget.onDuplicate, icon: const Icon(Icons.copy_outlined), label: const Text('Duplicate')),
              const Spacer(),
              if (widget.canRemove) IconButton(tooltip: 'Remove item', onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline)),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        const Icon(Icons.check_box, color: AppColors.active, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class StaticSelect extends StatelessWidget {
  const StaticSelect(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Row(
      children: [
        Expanded(child: Text(value)),
        const Icon(Icons.keyboard_arrow_down),
      ],
    ),
  );
}

class _ItemInfoSection extends StatelessWidget {
  const _ItemInfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [SectionTitle(title), ...children],
  );
}

class ItemImageUpload extends StatefulWidget {
  const ItemImageUpload({super.key});

  @override
  State<ItemImageUpload> createState() => _ItemImageUploadState();
}

class _ItemImageUploadState extends State<ItemImageUpload> {
  Uint8List? imageBytes;
  bool dragging = false;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.laptop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Item Image', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropTarget(
          onDragEntered: (_) => setState(() => dragging = true),
          onDragExited: (_) => setState(() => dragging = false),
          onDragDone: (details) async {
            setState(() => dragging = false);
            if (details.files.isNotEmpty) {
              await _setImage(await details.files.first.readAsBytes());
            }
          },
          child: InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: desktop ? 290 : 190,
              decoration: BoxDecoration(
                color: dragging
                    ? AppColors.primary.withValues(alpha: .08)
                    : Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dragging ? AppColors.primary : AppColors.divider,
                  width: dragging ? 2 : 1,
                ),
              ),
              child: imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                          color: AppColors.active,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          desktop
                              ? 'Drag & drop an image here'
                              : 'Tap to upload an image',
                          textAlign: TextAlign.center,
                        ),
                        if (desktop) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'or Browse',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.memory(imageBytes!, fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
        if (imageBytes != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => imageBytes = null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove image'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result?.files.single.bytes != null) {
      await _setImage(result!.files.single.bytes!);
    }
  }

  Future<void> _setImage(Uint8List bytes) async {
    if (!mounted) return;
    // The selected image is intentionally local form state; save APIs stay unchanged.
    setState(() => imageBytes = bytes);
  }
}

Widget field(
  TextEditingController c,
  String label, {
  String? prefix,
  bool number = false,
  int lines = 1,
  ValueChanged<String>? onChanged,
}) => TextField(
  controller: c,
  maxLines: lines,
  keyboardType: number ? TextInputType.number : TextInputType.text,
  onChanged: onChanged,
  decoration: InputDecoration(
    labelText: label,
    prefixText: prefix == null ? null : '$prefix  ',
    alignLabelWithHint: lines > 1,
  ),
);

class NewAdjustmentPage extends ConsumerStatefulWidget {
  const NewAdjustmentPage({super.key});
  @override
  ConsumerState<NewAdjustmentPage> createState() => _NewAdjustmentPageState();
}

class _NewAdjustmentPageState extends ConsumerState<NewAdjustmentPage> {
  final quantity = TextEditingController();
  final reference = TextEditingController(
    text: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
  );
  final description = TextEditingController();
  int? itemId;
  String reason = 'Stock Count Variance';
  bool applyNow = true;
  bool saving = false;

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'New Inventory Adjustment',
    saving: saving,
    onSave: save,
    children: [
      ref
          .watch(itemsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Unable to load items: $e'),
            data: (items) => DropdownButtonFormField<int>(
              initialValue: itemId,
              decoration: const InputDecoration(labelText: 'Item*'),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.name} · Stock ${item.stockOnHand.toStringAsFixed(0)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => itemId = value),
            ),
          ),
      const SizedBox(height: 14),
      field(quantity, 'Quantity Adjusted*', number: true),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: reason,
        decoration: const InputDecoration(labelText: 'Reason*'),
        items: const ['Stock Count Variance', 'Damaged Goods', 'Theft', 'Other']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => reason = value ?? reason),
      ),
      const SizedBox(height: 14),
      field(reference, 'Reference Number*'),
      const SizedBox(height: 14),
      field(description, 'Description', lines: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: applyNow,
        onChanged: (value) => setState(() => applyNow = value),
        title: Text(applyNow ? 'Apply stock adjustment now' : 'Save as draft'),
      ),
    ],
  );

  Future<void> save() async {
    final change = double.tryParse(quantity.text);
    if (itemId == null ||
        change == null ||
        change == 0 ||
        reference.text.trim().isEmpty) {
      return;
    }
    setState(() => saving = true);
    await ref
        .read(booksRepositoryProvider)
        .addAdjustment(
          AdjustmentDraft(
            itemId: itemId!,
            quantityAdjusted: change,
            reason: reason,
            referenceNumber: reference.text.trim(),
            description: description.text.trim(),
            applyNow: applyNow,
          ),
        );
    ref.invalidate(adjustmentsProvider);
    ref.invalidate(itemsProvider);
    ref.invalidate(dashboardMetricsProvider);
    if (mounted) context.pop();
  }
}
