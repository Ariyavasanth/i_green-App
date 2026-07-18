import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visual_effects.dart';
import '../../books/domain/books_repository.dart';
import '../../books/providers/books_providers.dart';
import 'widgets/quote_item_table.dart';
import 'widgets/quote_totals_section.dart';
import 'widgets/searchable_field.dart';

const _pdfTemplateOptions = [
  'Spreadsheet Template',
  'Standard Template',
  'Service Template',
];

/// Zoho Books-style "New Quote" creation form.
///
/// Registered at `/quotes/new` (see `app_router.dart`). Saves through the
/// existing [BooksRepository.addTransaction] contract so the quote list,
/// dashboard metrics and quote→invoice conversion flow all keep working
/// unchanged; the richer line-item/tax/attachment UI here is local form
/// state that gets rolled up into the [TransactionDraft] fields the backend
/// already understands (see [_save]).
class QuoteFormScreen extends ConsumerStatefulWidget {
  const QuoteFormScreen({super.key});

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _customerController = TextEditingController();
  final _quoteNumberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _advanceAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final _termsController = TextEditingController(
    text:
        '1. Please quote the above quote number when remitting payment.\n'
        '2. This quotation is valid for 15 days from the date of issue.',
  );

  Customer? _selectedCustomer;
  DateTime _quoteDate = DateTime.now();
  DateTime? _expiryDate;
  String? _salesperson;
  String? _projectName;
  String _pdfTemplate = _pdfTemplateOptions.first;
  bool _discountIsPercent = true;
  TaxAdjustmentType _taxAdjustmentType = TaxAdjustmentType.none;
  double _taxAdjustmentRate = taxAdjustmentRateOptions.first;
  bool _advanceReceiveEnabled = false;
  bool _saving = false;
  final List<QuoteLineItem> _lines = [QuoteLineItem()];
  final List<PlatformFile> _attachments = [];

  // Mobile-only UI state: which collapsible sections are expanded, and a key
  // used to auto-scroll to Quote Details once a customer is picked.
  bool _notesExpanded = false;
  bool _termsExpanded = false;
  final _quoteDetailsSectionKey = GlobalKey();

  static const _salespeople = ['Anwar', 'Priya', 'Ravi Kumar'];

  @override
  void initState() {
    super.initState();
    _quoteNumberController.text = _generateQuoteNumber();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _quoteNumberController.dispose();
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

  String _generateQuoteNumber() => 'QT-${DateTime.now().millisecondsSinceEpoch % 100000}';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final catalog = ref.watch(itemsProvider).valueOrNull ?? const <BookItem>[];
    final subTotal = _lines.fold<double>(0, (sum, l) => sum + l.amount);
    final taxTotal = _lines.fold<double>(0, (sum, l) => sum + l.taxAmount);

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < AppBreakpoints.tablet;
        if (isMobile) {
          return _buildMobile(customers: customers, catalog: catalog, subTotal: subTotal, taxTotal: taxTotal);
        }
        return _buildDesktop(customers: customers, catalog: catalog, subTotal: subTotal, taxTotal: taxTotal);
      },
    );
  }

  /// Original desktop/tablet layout — unchanged from before the mobile UX
  /// refactor. Kept fully intact so desktop rendering never regresses.
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
                                QuoteItemTable(
                                  lines: _lines,
                                  catalog: catalog,
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
                                ),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final totals = QuoteTotalsSection(
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
                                    if (constraints.maxWidth < AppBreakpoints.laptop) return totals;
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: SizedBox(width: 380, child: totals),
                                    );
                                  },
                                ),
                                const SizedBox(height: 28),
                                _notesAndTerms(),
                                const SizedBox(height: 20),
                                _attachmentsSection(),
                                const SizedBox(height: 14),
                                Text.rich(
                                  TextSpan(
                                    text: 'Additional Fields: ',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    children: [
                                      TextSpan(
                                        text: 'Start adding custom fields for your quotes.',
                                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Custom fields settings coming soon.')),
                                          ),
                                      ),
                                    ],
                                  ),
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
          _Footer(
            saving: _saving,
            pdfTemplate: _pdfTemplate,
            onSaveDraft: () => _save(sendAfterSave: false),
            onSaveAndSend: () => _save(sendAfterSave: true),
            onCancel: () => context.pop(),
            onChangeTemplate: _showTemplatePicker,
          ),
        ],
      ),
    );
  }

  /// Mobile layout: sticky compact bottom bar, section-grouped form with
  /// collapsible Notes/Terms, a compact collapsible item table, a floating
  /// "Add Item" action, and tighter spacing throughout. Desktop rendering
  /// above is untouched by any of this.
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
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 88),
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileSectionLabel('Customer Information'),
                          const SizedBox(height: 10),
                          SearchableField<Customer>(
                            label: 'Customer Name',
                            required: true,
                            controller: _customerController,
                            options: customers,
                            displayStringForOption: (c) => c.name,
                            optionSubtitle: (c) => c.company,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Customer Name is required' : null,
                            onSelected: (customer) {
                              setState(() {
                                _selectedCustomer = customer;
                                _projectName = null;
                              });
                              _scrollToQuoteDetails();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      key: _quoteDetailsSectionKey,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileSectionLabel('Quote Details'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _quoteNumberController,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Quote# is required' : null,
                            decoration: InputDecoration(
                              labelText: 'Quote#*',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: 'Generate new number',
                                onPressed: () => setState(() => _quoteNumberController.text = _generateQuoteNumber()),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _referenceController,
                            decoration: const InputDecoration(labelText: 'Reference#'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _DateField(
                                  label: 'Quote Date*',
                                  value: _quoteDate,
                                  format: _dateFormat,
                                  onTap: () => _pickDate(isExpiry: false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DateField(
                                  label: 'Expiry Date',
                                  value: _expiryDate,
                                  format: _dateFormat,
                                  placeholder: 'dd/MM/yyyy',
                                  onTap: () => _pickDate(isExpiry: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ClearableDropdown(
                            label: 'Salesperson',
                            value: _salesperson,
                            options: _salespeople,
                            onChanged: (v) => setState(() => _salesperson = v),
                          ),
                          const SizedBox(height: 12),
                          _ClearableDropdown(
                            label: 'Project Name',
                            value: _projectName,
                            options: const [],
                            enabled: _selectedCustomer != null,
                            helperText: _selectedCustomer == null
                                ? 'Select a customer to associate a project.'
                                : 'No projects found for this customer.',
                            onChanged: (v) => setState(() => _projectName = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: QuoteItemTable(
                        lines: _lines,
                        catalog: catalog,
                        showInlineActionButtons: false,
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileSectionLabel('Totals'),
                          const SizedBox(height: 10),
                          QuoteTotalsSection(
                            compact: true,
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
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _MobileCollapsibleSection(
                            title: 'Customer Notes',
                            expanded: _notesExpanded,
                            onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
                            child: TextFormField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Will be displayed on the quote',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 14, endIndent: 14),
                          _MobileCollapsibleSection(
                            title: 'Terms & Conditions',
                            expanded: _termsExpanded,
                            onToggle: () => setState(() => _termsExpanded = !_termsExpanded),
                            child: TextFormField(
                              controller: _termsController,
                              maxLines: 4,
                              decoration: const InputDecoration(alignLabelWithHint: true),
                            ),
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
                          _mobileSectionLabel('Attachments'),
                          const SizedBox(height: 10),
                          _mobileAttachmentsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: 'Additional Fields: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Start adding custom fields for your quotes.',
                            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Custom fields settings coming soon.')),
                              ),
                          ),
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
        pdfTemplate: _pdfTemplate,
        onSaveDraft: () => _save(sendAfterSave: false),
        onSaveAndSend: () => _save(sendAfterSave: true),
        onMore: _showMoreActionsSheet,
      ),
    );
  }

  Widget _mobileSectionLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3),
  );

  Widget _mobileAttachmentsSection() => Column(
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
                Expanded(child: Text(file.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                Text('${(file.size / 1024).toStringAsFixed(0)} KB', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  void _scrollToQuoteDetails() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _quoteDetailsSectionKey.currentContext;
      if (sectionContext == null) return;
      Scrollable.ensureVisible(sectionContext, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.05);
    });
  }

  Future<void> _showAddItemActions(List<BookItem> catalog) async {
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
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'single') {
      setState(() => _lines.add(QuoteLineItem()));
      return;
    }
    final result = await showBulkAddItemsDialog(context, catalog);
    if (!mounted || result == null || result.isEmpty) return;
    setState(() => _lines.addAll(result.map((item) => QuoteLineItem(item: item, rate: item.rate, taxPercent: item.taxRate))));
  }

  Future<void> _showMoreActionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF Template'),
              subtitle: Text(_pdfTemplate),
              onTap: () {
                Navigator.pop(sheetContext);
                _showTemplatePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.pop();
              },
            ),
          ],
        ),
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
          validator: (value) => value == null || value.trim().isEmpty ? 'Customer Name is required' : null,
          onSelected: (customer) => setState(() {
            _selectedCustomer = customer;
            _projectName = null;
          }),
        ),
        TextFormField(
          controller: _quoteNumberController,
          validator: (v) => v == null || v.trim().isEmpty ? 'Quote# is required' : null,
          decoration: InputDecoration(
            labelText: 'Quote#*',
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Generate new number',
              onPressed: () => setState(() => _quoteNumberController.text = _generateQuoteNumber()),
            ),
          ),
        ),
        TextFormField(
          controller: _referenceController,
          decoration: const InputDecoration(labelText: 'Reference#'),
        ),
        _DateField(
          label: 'Quote Date*',
          value: _quoteDate,
          format: _dateFormat,
          onTap: () => _pickDate(isExpiry: false),
        ),
        _DateField(
          label: 'Expiry Date',
          value: _expiryDate,
          format: _dateFormat,
          placeholder: 'dd/MM/yyyy',
          onTap: () => _pickDate(isExpiry: true),
        ),
        _ClearableDropdown(
          label: 'Salesperson',
          value: _salesperson,
          options: _salespeople,
          onChanged: (v) => setState(() => _salesperson = v),
        ),
        _ClearableDropdown(
          label: 'Project Name',
          value: _projectName,
          options: const [],
          enabled: _selectedCustomer != null,
          helperText: _selectedCustomer == null
              ? 'Select a customer to associate a project.'
              : 'No projects found for this customer.',
          onChanged: (v) => setState(() => _projectName = v),
        ),
      ];
      if (!twoColumn) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in fields) ...[f, const SizedBox(height: 14)],
          ],
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

  Widget _notesAndTerms() => LayoutBuilder(
    builder: (context, constraints) {
      final notes = TextFormField(
        controller: _notesController,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Customer Notes',
          hintText: 'Will be displayed on the quote',
          alignLabelWithHint: true,
        ),
      );
      final terms = TextFormField(
        controller: _termsController,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Terms & Conditions', alignLabelWithHint: true),
      );
      if (constraints.maxWidth < AppBreakpoints.tablet) {
        return Column(children: [notes, const SizedBox(height: 14), terms]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: notes), const SizedBox(width: 20), Expanded(child: terms)],
      );
    },
  );

  Widget _attachmentsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Attach File(s) to Quote', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 8),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Upload File'), SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, size: 16)],
            ),
          ),
        ],
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
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(file.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                Text('${(file.size / 1024).toStringAsFixed(0)} KB', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _attachments.remove(file)),
                ),
              ],
            ),
          ),
      ],
    ],
  );

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

  Future<void> _pickDate({required bool isExpiry}) async {
    final initial = isExpiry ? (_expiryDate ?? _quoteDate) : _quoteDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isExpiry ? _quoteDate : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiryDate = picked;
      } else {
        _quoteDate = picked;
        if (_expiryDate != null && _expiryDate!.isBefore(_quoteDate)) _expiryDate = null;
      }
    });
  }

  Future<void> _showTemplatePicker() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('PDF Template'),
        children: [
          for (final template in _pdfTemplateOptions)
            ListTile(
              title: Text(template),
              trailing: template == _pdfTemplate ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(context, template),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _pdfTemplate = picked);
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
            type: TransactionType.quote,
            customer: _selectedCustomer?.name ?? _customerController.text.trim(),
            customerId: _selectedCustomer?.id,
            number: _quoteNumberController.text.trim(),
            date: _quoteDate,
            dueDate: _expiryDate,
            referenceNumber: _referenceController.text.trim(),
            amount: total.toDouble(),
            discount: discountAmount,
            taxAmount: taxTotal,
            amountPaid: amountPaid,
            notes: _notesController.text.trim(),
            terms: _termsController.text.trim(),
          ),
        );
    ref.invalidate(transactionsProvider(TransactionType.quote));
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
        const Icon(Icons.request_quote_outlined, color: AppColors.active, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('New Quote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: onClose),
      ],
    ),
  );
}

/// A tap-to-expand section used for Customer Notes / Terms & Conditions on
/// mobile: collapsed by default so their multi-line text fields don't push
/// the rest of the form down the page.
class _MobileCollapsibleSection extends StatelessWidget {
  const _MobileCollapsibleSection({
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
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
      if (expanded)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: child,
        ),
    ],
  );
}

/// Compact sticky bottom action bar for mobile: only the two primary actions
/// (Save as Draft / Save and Send) stay always visible; Cancel and the PDF
/// Template picker move behind the "More actions" overflow button.
class _MobileFooter extends StatelessWidget {
  const _MobileFooter({
    required this.saving,
    required this.pdfTemplate,
    required this.onSaveDraft,
    required this.onSaveAndSend,
    required this.onMore,
  });

  final bool saving;
  final String pdfTemplate;
  final VoidCallback onSaveDraft;
  final VoidCallback onSaveAndSend;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: saving ? null : onSaveDraft,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(saving ? 'Saving...' : 'Save as Draft', overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: saving ? null : onSaveAndSend,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Text('Save and Send', overflow: TextOverflow.ellipsis, maxLines: 1),
              label: const Icon(Icons.keyboard_arrow_down, size: 18),
            ),
          ),
          IconButton(
            onPressed: onMore,
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saving,
    required this.pdfTemplate,
    required this.onSaveDraft,
    required this.onSaveAndSend,
    required this.onCancel,
    required this.onChangeTemplate,
  });

  final bool saving;
  final String pdfTemplate;
  final VoidCallback onSaveDraft;
  final VoidCallback onSaveAndSend;
  final VoidCallback onCancel;
  final VoidCallback onChangeTemplate;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final saveDraft = ElevatedButton(
            onPressed: saving ? null : onSaveDraft,
            child: Text(saving ? 'Saving...' : 'Save as Draft'),
          );
          final saveAndSend = FilledButton.icon(
            onPressed: saving ? null : onSaveAndSend,
            icon: const Text('Save and Send'),
            label: const Icon(Icons.keyboard_arrow_down, size: 18),
          );
          final cancel = OutlinedButton(
            onPressed: saving ? null : onCancel,
            child: const Text('Cancel'),
          );
          final pdfRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PDF Template: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text("'$pdfTemplate'", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: onChangeTemplate,
                style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 6)),
                child: const Text('Change', style: TextStyle(fontSize: 11)),
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                saveDraft,
                const SizedBox(height: 8),
                saveAndSend,
                const SizedBox(height: 8),
                cancel,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: pdfRow),
              ],
            );
          }
          return Row(
            children: [
              saveDraft,
              const SizedBox(width: 10),
              saveAndSend,
              const SizedBox(width: 10),
              cancel,
              const Spacer(),
              pdfRow,
            ],
          );
        },
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.format, required this.onTap, this.placeholder});
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
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
      child: Text(
        value != null ? format.format(value!) : (placeholder ?? ''),
        style: value != null ? null : const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _ClearableDropdown extends StatelessWidget {
  const _ClearableDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: !enabled
        ? null
        : () async {
            final picked = await showMenu<String>(
              context: context,
              position: const RelativeRect.fromLTRB(100, 300, 100, 100),
              items: options.isEmpty
                  ? [const PopupMenuItem(enabled: false, child: Text('No options available'))]
                  : options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
            );
            if (picked != null) onChanged(picked);
          },
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        enabled: enabled,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: enabled ? () => onChanged(null) : null,
              )
            : const Icon(Icons.keyboard_arrow_down),
      ),
      child: Text(value ?? '', style: enabled ? null : const TextStyle(color: AppColors.textSecondary)),
    ),
  );
}
