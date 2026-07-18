import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/visual_effects.dart';
import '../../../quotes/presentation/widgets/quote_item_table.dart';
import '../../../quotes/presentation/widgets/quote_totals_section.dart';
import '../../../quotes/presentation/widgets/searchable_field.dart';
import '../../domain/books_repository.dart';
import '../../providers/books_providers.dart';

const _salespeople = ['Anwar', 'Priya', 'Ravi Kumar'];
const _paymentTermsOptions = ['Due on Receipt', 'Net 15', 'Net 30', 'Net 45', 'Net 60'];
const _deliveryMethodOptions = ['Courier', 'Road', 'Air', 'Hand Delivery'];

/// Zoho Books-style "New Sales Order" creation form, with full feature
/// parity on every screen size: a stacked, collapsible layout on phones and
/// a multi-column grid + data table on tablet/desktop (mirrors
/// [QuoteFormScreen]'s own `_buildMobile`/`_buildDesktop` split).
///
/// Returned by [NewTransactionPage] whenever `type == TransactionType.salesOrder`
/// — it is not a routed screen, `/sales-orders/new` still resolves to
/// [NewTransactionPage]. Saves through the existing
/// [BooksRepository.addTransaction] contract so the sales order list,
/// dashboard metrics, etc. all keep working unchanged; fields with no
/// backing column (Salesperson, Payment Terms, Delivery Method) are local
/// form state only, matching the precedent already set by the Quote form's
/// own Salesperson/Project Name fields.
class SalesOrderForm extends ConsumerStatefulWidget {
  const SalesOrderForm({super.key});

  @override
  ConsumerState<SalesOrderForm> createState() => _SalesOrderFormState();
}

class _SalesOrderFormState extends ConsumerState<SalesOrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _customerController = TextEditingController();
  final _numberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _advanceAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();

  Customer? _selectedCustomer;
  DateTime _orderDate = DateTime.now();
  DateTime? _expectedShipmentDate;
  String? _salesperson;
  String? _paymentTerms;
  String? _deliveryMethod;
  bool _discountIsPercent = true;
  TaxAdjustmentType _taxAdjustmentType = TaxAdjustmentType.none;
  double _taxAdjustmentRate = taxAdjustmentRateOptions.first;
  bool _advanceReceiveEnabled = false;
  bool _saving = false;
  final List<QuoteLineItem> _lines = [QuoteLineItem()];
  final List<PlatformFile> _attachments = [];

  bool _notesExpanded = false;
  bool _termsExpanded = false;

  @override
  void initState() {
    super.initState();
    _numberController.text = _generateNumber();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _numberController.dispose();
    _referenceController.dispose();
    _discountController.dispose();
    _advanceAmountController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String _generateNumber() => 'SO-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final catalog = ref.watch(itemsProvider).valueOrNull ?? const <BookItem>[];
    final subTotal = _lines.fold<double>(0, (sum, l) => sum + l.amount);
    final taxTotal = _lines.fold<double>(0, (sum, l) => sum + l.taxAmount);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tablet) {
          return _buildMobile(customers: customers, catalog: catalog, subTotal: subTotal, taxTotal: taxTotal);
        }
        return _buildDesktop(customers: customers, catalog: catalog, subTotal: subTotal, taxTotal: taxTotal);
      },
    );
  }

  // ---------------------------------------------------------------------
  // Mobile layout: sticky bottom action bar, section-grouped single-column
  // form with collapsible Notes/Terms, expandable item cards driven by a
  // floating "Add Item" action.
  // ---------------------------------------------------------------------
  Widget _buildMobile({
    required List<Customer> customers,
    required List<BookItem> catalog,
    required double subTotal,
    required double taxTotal,
  }) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _Header(onClose: () => context.pop()),
          Expanded(
            child: FadeSlideIn(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Customer Information'),
                          const SizedBox(height: 10),
                          SearchableField<Customer>(
                            label: 'Customer Name',
                            required: true,
                            controller: _customerController,
                            options: customers,
                            displayStringForOption: (c) => c.name,
                            optionSubtitle: (c) => c.company,
                            validator: (value) =>
                                value == null || value.trim().isEmpty ? 'Customer Name is required' : null,
                            onSelected: (customer) => setState(() => _selectedCustomer = customer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Sales Order Details'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _referenceController,
                            decoration: const InputDecoration(labelText: 'Reference Number'),
                          ),
                          const SizedBox(height: 12),
                          _numberField(),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _orderDateField()),
                              const SizedBox(width: 12),
                              Expanded(child: _shipDateField()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _paymentTermsField(),
                          const SizedBox(height: 12),
                          _deliveryMethodField(),
                          const SizedBox(height: 12),
                          _salespersonField(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: _itemTable(catalog, showInlineActionButtons: false),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Summary'),
                          const SizedBox(height: 10),
                          _totalsSection(subTotal, taxTotal, compact: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _CollapsibleSection(
                            title: 'Customer Notes',
                            expanded: _notesExpanded,
                            onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
                            child: _notesField(),
                          ),
                          const Divider(height: 1, indent: 14, endIndent: 14),
                          _CollapsibleSection(
                            title: 'Terms & Conditions',
                            expanded: _termsExpanded,
                            onToggle: () => setState(() => _termsExpanded = !_termsExpanded),
                            child: _termsField(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel('Attachments'),
                          const SizedBox(height: 10),
                          _attachmentsSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemActions(catalog),
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _MobileFooter(
        saving: _saving,
        onSaveDraft: () => _save(sendAfterSave: false),
        onSaveAndSend: () => _save(sendAfterSave: true),
        onCancel: () => context.pop(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop/tablet layout: multi-column field grid, the same [QuoteItemTable]
  // rendering as a real data table (it already branches on width itself),
  // a right-aligned totals box, side-by-side Notes/Terms, and an inline
  // footer row — same information as mobile, laid out the desktop way.
  // ---------------------------------------------------------------------
  Widget _buildDesktop({
    required List<Customer> customers,
    required List<BookItem> catalog,
    required double subTotal,
    required double taxTotal,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.canvas),
      child: Column(
        children: [
          _Header(onClose: () => context.pop()),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = AppLayout.gutter(constraints.maxWidth);
                return FadeSlideIn(
                  child: ResponsiveContent(
                    maxWidth: 1200,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
                        children: [
                          GlassPanel(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _topFieldsGrid(customers),
                                const SizedBox(height: 28),
                                _itemTable(catalog, showInlineActionButtons: true),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totals = _totalsSection(subTotal, taxTotal, compact: false);
                                    if (constraints.maxWidth < AppBreakpoints.laptop) return totals;
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: SizedBox(width: 380, child: totals),
                                    );
                                  },
                                ),
                                const SizedBox(height: 28),
                                _notesAndTermsDesktop(),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionLabel('Attachments'),
                                    const SizedBox(height: 10),
                                    _attachmentsSection(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _DesktopFooter(
            saving: _saving,
            onSaveDraft: () => _save(sendAfterSave: false),
            onSaveAndSend: () => _save(sendAfterSave: true),
            onCancel: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _topFieldsGrid(List<Customer> customers) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumn = constraints.maxWidth >= AppBreakpoints.tablet;
      final fields = [
        SearchableField<Customer>(
          label: 'Customer Name',
          required: true,
          controller: _customerController,
          options: customers,
          displayStringForOption: (c) => c.name,
          optionSubtitle: (c) => c.company,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Customer Name is required' : null,
          onSelected: (customer) => setState(() => _selectedCustomer = customer),
        ),
        TextFormField(
          controller: _referenceController,
          decoration: const InputDecoration(labelText: 'Reference Number'),
        ),
        _numberField(),
        _orderDateField(),
        _shipDateField(),
        _paymentTermsField(),
        _deliveryMethodField(),
        _salespersonField(),
      ];
      if (!twoColumn) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final f in fields) ...[f, const SizedBox(height: 14)]],
        );
      }
      const gap = 20.0;
      final columnWidth = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: 16,
        children: [for (final f in fields) SizedBox(width: columnWidth, child: f)],
      );
    },
  );

  Widget _notesAndTermsDesktop() => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < AppBreakpoints.tablet) {
        return Column(children: [_notesField(), const SizedBox(height: 14), _termsField()]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: _notesField()), const SizedBox(width: 20), Expanded(child: _termsField())],
      );
    },
  );

  // ---------------------------------------------------------------------
  // Shared field builders (identical fields on both layouts).
  // ---------------------------------------------------------------------

  Widget _numberField() => TextFormField(
    controller: _numberController,
    validator: (v) => v == null || v.trim().isEmpty ? 'Sales Order# is required' : null,
    decoration: InputDecoration(
      labelText: 'Sales Order#*',
      suffixIcon: IconButton(
        icon: const Icon(Icons.refresh, size: 18),
        tooltip: 'Generate new number',
        onPressed: () => setState(() => _numberController.text = _generateNumber()),
      ),
    ),
  );

  Widget _orderDateField() => _DateField(
    label: 'Sales Order Date*',
    value: _orderDate,
    format: _dateFormat,
    onTap: () => _pickDate(isShipment: false),
  );

  Widget _shipDateField() => _DateField(
    label: 'Expected Shipment Date',
    value: _expectedShipmentDate,
    format: _dateFormat,
    placeholder: 'dd/MM/yyyy',
    onTap: () => _pickDate(isShipment: true),
  );

  Widget _paymentTermsField() => DropdownButtonFormField<String>(
    initialValue: _paymentTerms,
    decoration: const InputDecoration(labelText: 'Payment Terms'),
    items: _paymentTermsOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
    onChanged: (v) => setState(() => _paymentTerms = v),
  );

  Widget _deliveryMethodField() => DropdownButtonFormField<String>(
    initialValue: _deliveryMethod,
    decoration: const InputDecoration(labelText: 'Delivery Method'),
    items: _deliveryMethodOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
    onChanged: (v) => setState(() => _deliveryMethod = v),
  );

  Widget _salespersonField() => DropdownButtonFormField<String>(
    initialValue: _salesperson,
    decoration: const InputDecoration(labelText: 'Salesperson'),
    items: _salespeople.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
    onChanged: (v) => setState(() => _salesperson = v),
  );

  Widget _notesField() => TextFormField(
    controller: _notesController,
    maxLines: 4,
    decoration: const InputDecoration(
      labelText: 'Customer Notes',
      hintText: 'Will be displayed on the sales order',
      alignLabelWithHint: true,
    ),
  );

  Widget _termsField() => TextFormField(
    controller: _termsController,
    maxLines: 4,
    decoration: const InputDecoration(labelText: 'Terms & Conditions', alignLabelWithHint: true),
  );

  Widget _itemTable(List<BookItem> catalog, {required bool showInlineActionButtons}) => QuoteItemTable(
    lines: _lines,
    catalog: catalog,
    showInlineActionButtons: showInlineActionButtons,
    onChanged: () => setState(() {}),
    onAddRow: () => setState(() => _lines.add(QuoteLineItem())),
    onAddRows: (items) => setState(
      () => _lines.addAll(
        items.map((item) => QuoteLineItem(item: item, rate: item.rate, taxPercent: item.taxRate)),
      ),
    ),
    onRemoveRow: (index) => setState(() {
      _lines.removeAt(index).dispose();
      if (_lines.isEmpty) _lines.add(QuoteLineItem());
    }),
    onClearAll: () => setState(() {
      for (final line in _lines) {
        line.dispose();
      }
      _lines
        ..clear()
        ..add(QuoteLineItem());
    }),
  );

  Widget _totalsSection(double subTotal, double taxTotal, {required bool compact}) => QuoteTotalsSection(
    compact: compact,
    subTotal: subTotal,
    taxTotal: taxTotal,
    discountController: _discountController,
    discountIsPercent: _discountIsPercent,
    onDiscountModeChanged: (v) => setState(() => _discountIsPercent = v),
    taxAdjustmentType: _taxAdjustmentType,
    onTaxAdjustmentTypeChanged: (v) => setState(() => _taxAdjustmentType = v),
    taxAdjustmentRate: _taxAdjustmentRate,
    onTaxAdjustmentRateChanged: (v) => setState(() => _taxAdjustmentRate = v),
    advanceReceiveEnabled: _advanceReceiveEnabled,
    onAdvanceReceiveToggled: (v) => setState(() => _advanceReceiveEnabled = v),
    advanceAmountController: _advanceAmountController,
    onChanged: () => setState(() {}),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.3,
    ),
  );

  Widget _attachmentsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _pickAttachments,
        icon: const Icon(Icons.attach_file, size: 18),
        label: const Text('Upload Files'),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'You can upload a maximum of 5 files, 10MB each',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      if (_attachments.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final file in _attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(file.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
                Text(
                  '${(file.size / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _attachments.remove(file)),
                ),
              ],
            ),
          ),
      ],
    ],
  );

  Future<void> _showAddItemActions(List<BookItem> catalog) async {
    final canDuplicate = _lines.isNotEmpty && !_lines.last.isEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('Add Item'),
              onTap: () => Navigator.pop(sheetContext, 'single'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppColors.primary),
              title: const Text('Add Bulk Items'),
              onTap: () => Navigator.pop(sheetContext, 'bulk'),
            ),
            ListTile(
              enabled: canDuplicate,
              leading: Icon(
                Icons.copy_all_outlined,
                color: canDuplicate ? AppColors.primary : AppColors.textSecondary,
              ),
              title: const Text('Duplicate Last Item'),
              onTap: () => Navigator.pop(sheetContext, 'duplicate'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'single') {
      setState(() => _lines.add(QuoteLineItem()));
      return;
    }
    if (choice == 'duplicate') {
      final last = _lines.last;
      setState(
        () => _lines.add(
          QuoteLineItem(
            item: last.item,
            quantity: last.quantity,
            rate: last.rate,
            taxPercent: last.taxPercent,
          ),
        ),
      );
      return;
    }
    final result = await showBulkAddItemsDialog(context, catalog);
    if (!mounted || result == null || result.isEmpty) return;
    setState(
      () => _lines.addAll(
        result.map((item) => QuoteLineItem(item: item, rate: item.rate, taxPercent: item.taxRate)),
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: false);
    if (result == null) return;
    final remaining = 5 - _attachments.length;
    if (remaining <= 0) {
      _showError('You can upload a maximum of 5 files.');
      return;
    }
    final tooLarge = result.files.any((f) => f.size > 10 * 1024 * 1024);
    if (tooLarge) {
      _showError('Each file must be 10MB or smaller.');
      return;
    }
    setState(() => _attachments.addAll(result.files.take(remaining)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate({required bool isShipment}) async {
    final initial = isShipment ? (_expectedShipmentDate ?? _orderDate) : _orderDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isShipment ? _orderDate : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isShipment) {
        _expectedShipmentDate = picked;
      } else {
        _orderDate = picked;
        if (_expectedShipmentDate != null && _expectedShipmentDate!.isBefore(_orderDate)) {
          _expectedShipmentDate = null;
        }
      }
    });
  }

  Future<void> _save({required bool sendAfterSave}) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _saving = true);
    final subTotal = _lines.fold<double>(0, (sum, l) => sum + l.amount);
    final taxTotal = _lines.fold<double>(0, (sum, l) => sum + l.taxAmount);
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    final discountAmount = _discountIsPercent ? subTotal * discountValue / 100 : discountValue;
    final taxAdjustmentAmount = _taxAdjustmentType == TaxAdjustmentType.none
        ? 0.0
        : (subTotal - discountAmount) * _taxAdjustmentRate / 100;
    final total = (subTotal - discountAmount + taxTotal - taxAdjustmentAmount).clamp(0, double.infinity);
    final amountPaid = _advanceReceiveEnabled ? (double.tryParse(_advanceAmountController.text) ?? 0) : 0.0;

    await ref
        .read(booksRepositoryProvider)
        .addTransaction(
          TransactionDraft(
            type: TransactionType.salesOrder,
            customer: _selectedCustomer?.name ?? _customerController.text.trim(),
            customerId: _selectedCustomer?.id,
            number: _numberController.text.trim(),
            date: _orderDate,
            dueDate: _expectedShipmentDate,
            referenceNumber: _referenceController.text.trim(),
            amount: total.toDouble(),
            discount: discountAmount,
            taxAmount: taxTotal,
            amountPaid: amountPaid,
            notes: _notesController.text.trim(),
            terms: _termsController.text.trim(),
          ),
        );
    ref.invalidate(transactionsProvider(TransactionType.salesOrder));
    if (mounted) context.pop();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_long_outlined, color: AppColors.active, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('New Sales Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: onClose),
      ],
    ),
  );
}

/// A tap-to-expand section used for Customer Notes / Terms & Conditions on
/// mobile: collapsed by default so their multi-line text fields don't push
/// the rest of the form down the page. Desktop shows both fields side by
/// side, always expanded, since there's room.
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.expand_more, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: child,
        ),
        crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 180),
        sizeCurve: Curves.easeInOut,
      ),
    ],
  );
}

/// Sticky bottom action bar for phones: Save as Draft and Save and Send stay
/// on one row, Cancel sits below — all three always reachable without
/// scrolling.
class _MobileFooter extends StatelessWidget {
  const _MobileFooter({
    required this.saving,
    required this.onSaveDraft,
    required this.onSaveAndSend,
    required this.onCancel,
  });

  final bool saving;
  final VoidCallback onSaveDraft;
  final VoidCallback onSaveAndSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: saving ? null : onSaveDraft,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(
                    saving ? 'Saving...' : 'Save as Draft',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : onSaveAndSend,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Save and Send', overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Inline bottom action bar for tablet/desktop — all three actions sit in a
/// single row since there's enough width, no stacking needed.
class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter({
    required this.saving,
    required this.onSaveDraft,
    required this.onSaveAndSend,
    required this.onCancel,
  });

  final bool saving;
  final VoidCallback onSaveDraft;
  final VoidCallback onSaveAndSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: saving ? null : onSaveDraft,
            child: Text(saving ? 'Saving...' : 'Save as Draft'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: saving ? null : onSaveAndSend,
            child: const Text('Save and Send'),
          ),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.format,
    required this.onTap,
    this.placeholder,
  });
  final String label;
  final DateTime? value;
  final DateFormat format;
  final VoidCallback onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(
        value != null ? format.format(value!) : (placeholder ?? ''),
        style: value != null ? null : const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}
