import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/expense_providers.dart';

class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({required this.onCancel, required this.onSaved, super.key});

  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _sac = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _scrollController = ScrollController();
  DateTime _date = DateTime.now();
  String? _expenseAccount;
  String? _paidThrough;
  String? _vendor;
  String? _gstTreatment;
  String? _source;
  String? _tax;
  bool _services = true;
  bool _reverseCharge = false;
  bool _taxExclusive = true;
  bool _dragging = false;
  bool _saving = false;
  bool _savingAndNew = false;
  String? _receiptName;

  static const _accounts = [
    'Travel Expense',
    'Transportation Expense',
    'Factory Expenses',
    'Office Supplies',
  ];
  static const _paidAccounts = [
    'Petty Cash',
    'Cash',
    'Bank Account',
    'Credit Card',
  ];
  static const _vendors = ['Local Shops', 'Porter', 'iGreen Technologies'];

  @override
  void dispose() {
    _amount.dispose();
    _sac.dispose();
    _reference.dispose();
    _notes.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: MediaQuery.sizeOf(context).width < 800
        ? AppColors.canvas
        : Colors.white,
    child: Column(
      children: [
        _tabs(),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 800 ? 16 : 20,
                  constraints.maxWidth < 800 ? 14 : 18,
                  constraints.maxWidth < 800 ? 16 : 20,
                  90,
                ),
                child: constraints.maxWidth >= 800
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth * .52,
                            child: _fields(),
                          ),
                          const SizedBox(width: 70),
                          _receiptBox(),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mobileIntro(),
                          _mobileCard(child: _fields()),
                          const SizedBox(height: 20),
                          _mobileSectionTitle(
                            Icons.receipt_long_outlined,
                            'Receipt',
                          ),
                          const SizedBox(height: 10),
                          _receiptBox(mobile: true),
                        ],
                      ),
              ),
            ),
          ),
        ),
        _footer(),
      ],
    ),
  );

  Widget _tabs() => SizedBox(
    height: 46,
    child: Row(
      children: [
        Container(
          margin: const EdgeInsets.only(left: 20),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.active, width: 2)),
          ),
          child: const Text(
            'Record Expense',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 14, 12, 10),
          child: Text(
            'Record Mileage',
            style: TextStyle(fontSize: 12, color: AppColors.active),
          ),
        ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width < 800)
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, size: 20),
          ),
      ],
    ),
  );

  Widget _mobileIntro() => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New expense',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Add the transaction details below',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mobileCard({required Widget child}) => Container(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (MediaQuery.sizeOf(context).width < 800) ...[
        _mobileSectionTitle(Icons.payments_outlined, 'Expense details'),
        const SizedBox(height: 12),
      ],
      _row('Date*', _dateField(), required: true),
      _row(
        'Expense Account*',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dropdown(
              _expenseAccount,
              'Select an account',
              _accounts,
              (v) => setState(() => _expenseAccount = v),
              required: true,
            ),
            const SizedBox(height: 3),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.format_list_bulleted, size: 13),
              label: const Text('Itemize'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 20),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        required: true,
      ),
      _row(
        'Amount*',
        Row(
          children: [
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: _border(),
              child: const Text('INR', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _input(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter an amount' : null,
              ),
            ),
          ],
        ),
        required: true,
      ),
      const SizedBox(height: 18),
      if (MediaQuery.sizeOf(context).width < 800) ...[
        _mobileSectionTitle(
          Icons.account_balance_wallet_outlined,
          'Payment & tax',
        ),
        const SizedBox(height: 12),
      ],
      _row(
        'Paid Through*',
        _dropdown(
          _paidThrough,
          'Select an account',
          _paidAccounts,
          (v) => setState(() => _paidThrough = v),
          required: true,
        ),
        required: true,
      ),
      _row(
        'Expense Type*',
        _mobileChoice(
          first: 'Goods',
          second: 'Services',
          secondSelected: _services,
          onFirst: () => setState(() => _services = false),
          onSecond: () => setState(() => _services = true),
        ),
        required: true,
      ),
      _row('SAC', TextFormField(controller: _sac, decoration: _input())),
      _row(
        'Vendor',
        Row(
          children: [
            Expanded(
              child: _dropdown(
                _vendor,
                '',
                _vendors,
                (v) => setState(() => _vendor = v),
              ),
            ),
            SizedBox(
              height: 38,
              width: 40,
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.active,
                  padding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Icon(Icons.search, size: 17),
              ),
            ),
          ],
        ),
      ),
      _row(
        'GST Treatment*',
        _dropdown(
          _gstTreatment,
          '',
          const ['Registered Business', 'Unregistered Business', 'Overseas'],
          (v) => setState(() => _gstTreatment = v),
          required: true,
        ),
        required: true,
      ),
      _row(
        'Source of Supply*',
        _dropdown(
          _source,
          'State/Province',
          const ['Tamil Nadu', 'Karnataka', 'Kerala', 'Maharashtra'],
          (v) => setState(() => _source = v),
          required: true,
        ),
        required: true,
      ),
      _row(
        'Destination of Supply*',
        _dropdown(
          'Tamil Nadu',
          '',
          const ['Tamil Nadu'],
          (_) {},
          prefix: '[TN] - ',
        ),
        required: true,
      ),
      _row(
        'Reverse Charge',
        CheckboxListTile(
          value: _reverseCharge,
          onChanged: (v) => setState(() => _reverseCharge = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'This transaction is applicable for reverse charge',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ),
      _row(
        'Tax',
        _dropdown(_tax, 'Select a Tax', const [
          'GST 5%',
          'GST 12%',
          'GST 18%',
          'GST 28%',
        ], (v) => setState(() => _tax = v)),
      ),
      _row(
        'Amount Is',
        _mobileChoice(
          first: 'Tax Inclusive',
          second: 'Tax Exclusive',
          secondSelected: _taxExclusive,
          onFirst: () => setState(() => _taxExclusive = false),
          onSecond: () => setState(() => _taxExclusive = true),
        ),
      ),
      _row(
        'Reference#',
        TextFormField(controller: _reference, decoration: _input()),
      ),
      _row(
        'Notes',
        TextFormField(controller: _notes, maxLines: 3, decoration: _input()),
      ),
    ],
  );

  Widget _row(String label, Widget field, {bool required = false}) {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    final cleanLabel = label.replaceAll('*', '');
    final labelWidget = mobile
        ? Text.rich(
            TextSpan(
              text: cleanLabel,
              children: required
                  ? [
                      TextSpan(
                        text: '  *',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ]
                  : const [],
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          )
        : Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: required ? Colors.red.shade400 : AppColors.textPrimary,
            ),
          );
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 16 : 10),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelWidget, const SizedBox(height: 7), field],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 145,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: labelWidget,
                  ),
                ),
                Expanded(child: field),
              ],
            ),
    );
  }

  Widget _mobileSectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.active),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: AppColors.divider)),
    ],
  );

  Widget _mobileChoice({
    required String first,
    required String second,
    required bool secondSelected,
    required VoidCallback onFirst,
    required VoidCallback onSecond,
  }) {
    if (MediaQuery.sizeOf(context).width >= 800) {
      return Row(
        children: [
          _radio(first, !secondSelected, onFirst),
          const SizedBox(width: 14),
          _radio(second, secondSelected, onSecond),
        ],
      );
    }
    Widget option(String text, bool selected, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.active.withValues(alpha: .10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.active : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 17,
                color: selected ? AppColors.active : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          option(first, !secondSelected, onFirst),
          option(second, secondSelected, onSecond),
        ],
      ),
    );
  }

  Widget _dateField() => InkWell(
    onTap: () async {
      final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (value != null) setState(() => _date = value);
    },
    child: InputDecorator(
      decoration: _input(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
      ),
      child: Text(
        DateFormat('dd/MM/yyyy').format(_date),
        style: const TextStyle(fontSize: 12),
      ),
    ),
  );

  Widget _dropdown(
    String? value,
    String hint,
    List<String> items,
    ValueChanged<String?> changed, {
    bool required = false,
    String prefix = '',
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    hint: Text(hint, style: const TextStyle(fontSize: 11)),
    decoration: _input(),
    items: items
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text('$prefix$item', style: const TextStyle(fontSize: 11)),
          ),
        )
        .toList(),
    onChanged: changed,
    validator: required ? (v) => v == null ? 'Select an option' : null : null,
  );

  Widget _radio(String label, bool selected, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 16,
          color: selected ? AppColors.active : AppColors.textSecondary,
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _receiptBox({bool mobile = false}) => DropTarget(
    onDragEntered: (_) => setState(() => _dragging = true),
    onDragExited: (_) => setState(() => _dragging = false),
    onDragDone: (details) => setState(() {
      _dragging = false;
      if (details.files.isNotEmpty) _receiptName = details.files.first.name;
    }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: mobile ? double.infinity : 250,
      height: mobile ? 190 : 300,
      decoration: BoxDecoration(
        color: _dragging ? AppColors.canvas : Colors.white,
        border: Border.all(color: AppColors.active, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            mobile ? Icons.cloud_upload_outlined : Icons.image_outlined,
            size: mobile ? 36 : 43,
            color: AppColors.active,
          ),
          SizedBox(height: mobile ? 9 : 15),
          Text(
            mobile ? 'Add a receipt' : 'Drag and Drop Your Receipts',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          const Text(
            'Maximum file size allowed is 10MB',
            style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickReceipt,
            icon: const Icon(Icons.upload_outlined, size: 16),
            label: const Text(
              'Upload your Files',
              style: TextStyle(fontSize: 11),
            ),
          ),
          if (_receiptName != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _receiptName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.active),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _pickReceipt() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (result != null && mounted) {
      setState(() => _receiptName = result.files.single.name);
    }
  }

  Widget _footer() {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: mobile ? 6 : 0),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 12 : 20,
            10,
            mobile ? 12 : 20,
            10,
          ),
          child: Row(
            children: [
              if (mobile)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              if (mobile) const SizedBox(width: 8),
              if (mobile)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save(true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: _savingAndNew
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save & New',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              if (mobile) const SizedBox(width: 8),
              if (mobile)
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.active,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: _saving && !_savingAndNew
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              if (!mobile)
                FilledButton(
                  onPressed: _saving ? null : () => _save(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.active,
                  ),
                  child: const Text(
                    'Save (Alt+S)',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              if (!mobile) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving ? null : () => _save(true),
                  child: const Text(
                    'Save and New (Alt+N)',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(bool keepOpen) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the required fields before saving.'),
        ),
      );
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    setState(() {
      _saving = true;
      _savingAndNew = keepOpen;
    });
    try {
      await ref
          .read(expenseRepositoryProvider)
          .addExpense(
            date: _date,
            account: _expenseAccount!,
            reference: _reference.text.trim(),
            vendor: _vendor ?? '',
            paidThrough: _paidThrough!,
            customer: '',
            status: 'NON-BILLABLE',
            amount: double.tryParse(_amount.text.trim()) ?? 0,
          );
      if (!mounted) return;
      ref.invalidate(expensesProvider);
      if (!keepOpen) {
        widget.onSaved();
        return;
      }
      _formKey.currentState!.reset();
      _amount.clear();
      _sac.clear();
      _reference.clear();
      _notes.clear();
      setState(() {
        _date = DateTime.now();
        _expenseAccount = null;
        _paidThrough = null;
        _vendor = null;
        _gstTreatment = null;
        _source = null;
        _tax = null;
        _services = true;
        _reverseCharge = false;
        _taxExclusive = true;
        _receiptName = null;
        _saving = false;
        _savingAndNew = false;
      });
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense saved. Ready for a new expense.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savingAndNew = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save expense: $error')));
    }
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    widget.onCancel();
  }

  InputDecoration _input({Widget? suffixIcon}) {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    return InputDecoration(
      isDense: true,
      filled: mobile,
      fillColor: mobile ? Colors.white : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 10,
        vertical: mobile ? 14 : 10,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 36),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.active),
      ),
      errorStyle: const TextStyle(fontSize: 9),
    );
  }

  BoxDecoration _border() => BoxDecoration(
    border: Border.all(color: AppColors.divider),
    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
  );
}
