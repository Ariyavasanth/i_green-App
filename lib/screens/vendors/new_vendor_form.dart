import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NewVendorForm extends StatefulWidget {
  const NewVendorForm({super.key});

  @override
  State<NewVendorForm> createState() => _NewVendorFormState();
}

class _NewVendorFormState extends State<NewVendorForm> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameKey = GlobalKey<FormFieldState<String>>();
  final _gstTreatmentKey = GlobalKey<FormFieldState<String>>();
  final _sourceOfSupplyKey = GlobalKey<FormFieldState<String>>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _companyName = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _workPhone = TextEditingController();
  final _mobile = TextEditingController();
  final _pan = TextEditingController();
  final _openingBalance = TextEditingController();

  String? _salutation;
  String? _gstTreatment;
  String? _sourceOfSupply;
  String _currency = 'INR - Indian Rupee';
  String _paymentTerms = 'Due on Receipt';
  String? _tds;
  bool _isMsmeRegistered = false;
  bool _showBanner = true;
  bool _showMoreDetails = false;
  bool _saving = false;
  int _documentCount = 0;
  int _selectedSection = 0;

  static const _sections = <String>[
    'Other Details',
    'Address',
    'Contact Persons',
    'Bank Details',
    'Custom Fields',
    'Reporting Tags',
    'Remarks',
  ];

  static const _gstTreatments = <String>[
    'Registered Business - Regular',
    'Registered Business - Composition',
    'Unregistered Business',
    'Consumer',
    'Overseas',
  ];

  static const _states = <String>[
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Delhi',
    'Gujarat',
    'Karnataka',
    'Kerala',
    'Maharashtra',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'West Bengal',
  ];

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _firstName,
      _lastName,
      _companyName,
      _displayName,
      _email,
      _workPhone,
      _mobile,
      _pan,
      _openingBalance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
        title: const Text('New Vendor'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 700;
            final horizontalPadding = isTablet ? 32.0 : 16.0;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showBanner) _buildInfoBanner(theme),
                        if (_showBanner) const SizedBox(height: 20),
                        _sectionTitle('Primary Contact'),
                        const SizedBox(height: 16),
                        _buildPrimaryContact(isTablet),
                        const SizedBox(height: 28),
                        _sectionTitle('Other Details'),
                        const SizedBox(height: 12),
                        _buildSectionSelector(),
                        const SizedBox(height: 20),
                        if (_selectedSection == 0)
                          _buildOtherDetails(isTablet)
                        else
                          _buildEmptySection(_sections[_selectedSection]),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _saving ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme) {
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Prefill Vendor details from the GST portal using the Vendor's GSTIN. ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  InkWell(
                    onTap: _prefill,
                    child: Text(
                      'Prefill',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _showBanner = false),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      );

  Widget _buildPrimaryContact(bool isTablet) {
    final nameFields = <Widget>[
      _dropdown(
        label: 'Salutation',
        value: _salutation,
        items: const ['Mr.', 'Mrs.', 'Ms.', 'Dr.'],
        onChanged: (value) => setState(() => _salutation = value),
      ),
      _textField(controller: _firstName, label: 'First Name'),
      _textField(controller: _lastName, label: 'Last Name'),
    ];

    return Column(
      children: [
        _responsiveRow(nameFields, isTablet),
        const SizedBox(height: 16),
        _textField(controller: _companyName, label: 'Company Name'),
        const SizedBox(height: 16),
        _textField(
          key: _displayNameKey,
          controller: _displayName,
          label: 'Display Name',
          required: true,
          suffixIcon: const Icon(Icons.keyboard_arrow_down),
          validator: _required('Display Name'),
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _email,
          label: 'Email Address',
          prefixIcon: const Icon(Icons.mail_outline),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return null;
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? null
                : 'Enter a valid email address';
          },
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _phoneField(_workPhone, 'Work Phone'),
            _phoneField(_mobile, 'Mobile'),
          ],
          isTablet,
        ),
      ],
    );
  }

  Widget _buildSectionSelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ChoiceChip(
          label: Text(_sections[index]),
          selected: _selectedSection == index,
          onSelected: (_) => setState(() => _selectedSection = index),
        ),
      ),
    );
  }

  Widget _buildOtherDetails(bool isTablet) {
    return Column(
      children: [
        _responsiveRow(
          [
            _dropdown(
              key: _gstTreatmentKey,
              label: 'GST Treatment',
              required: true,
              value: _gstTreatment,
              items: _gstTreatments,
              validator: _required('GST Treatment'),
              onChanged: (value) => setState(() => _gstTreatment = value),
            ),
            _dropdown(
              key: _sourceOfSupplyKey,
              label: 'Source of Supply',
              required: true,
              value: _sourceOfSupply,
              items: _states,
              validator: _required('Source of Supply'),
              onChanged: (value) => setState(() => _sourceOfSupply = value),
            ),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _textField(controller: _pan, label: 'PAN'),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('This vendor is MSME registered'),
          value: _isMsmeRegistered,
          onChanged: (value) => setState(() => _isMsmeRegistered = value),
        ),
        const SizedBox(height: 10),
        _responsiveRow(
          [
            _dropdown(
              label: 'Currency',
              value: _currency,
              items: const ['INR - Indian Rupee'],
              onChanged: (value) => setState(() => _currency = value!),
            ),
            _textField(
              controller: _openingBalance,
              label: 'Opening Balance',
              prefixText: '₹ ',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _dropdown(
              label: 'Payment Terms',
              value: _paymentTerms,
              items: const [
                'Due on Receipt',
                'Net 15',
                'Net 30',
                'Net 45',
                'Net 60',
              ],
              onChanged: (value) => setState(() => _paymentTerms = value!),
            ),
            _dropdown(
              label: 'TDS',
              value: _tds,
              hint: 'Select a Tax',
              items: const [
                'Commission or Brokerage',
                'Professional Fees',
                'Contractor Payment',
              ],
              onChanged: (value) => setState(() => _tds = value),
            ),
          ],
          isTablet,
        ),
        const SizedBox(height: 22),
        _buildDocuments(),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _showMoreDetails = !_showMoreDetails),
            icon: Icon(
              _showMoreDetails ? Icons.expand_less : Icons.expand_more,
            ),
            label: const Text('Add more details'),
          ),
        ),
        if (_showMoreDetails) ...[
          const SizedBox(height: 8),
          _textField(label: 'Website'),
          const SizedBox(height: 16),
          _textField(label: 'Department'),
        ],
      ],
    );
  }

  Widget _buildDocuments() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documents', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDocuments,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              _documentCount == 0
                  ? 'Upload Files'
                  : '$_documentCount file(s) selected',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can upload a maximum of 10 files, 10MB each',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String section) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$section details can be added here.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _responsiveRow(List<Widget> children, bool isTablet) {
    if (!isTablet) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _phoneField(TextEditingController controller, String label) {
    return _textField(
      controller: controller,
      label: label,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      prefixIcon: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: '+91',
          padding: const EdgeInsets.only(left: 12),
          items: const [
            DropdownMenuItem(value: '+91', child: Text('+91')),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }

  Widget _textField({
    Key? key,
    TextEditingController? controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        label: _fieldLabel(label, required),
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _dropdown({
    Key? key,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: value,
      isExpanded: true,
      hint: hint == null ? null : Text(hint),
      decoration: InputDecoration(label: _fieldLabel(label, required)),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(growable: false),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _fieldLabel(String label, bool required) {
    if (!required) return Text(label);
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }

  String? Function(String?) _required(String label) => (value) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  void _prefill() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GST portal prefill will be available soon.')),
    );
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    if (result.files.length > 10 ||
        result.files.any((file) => file.size > 10 * 1024 * 1024)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select up to 10 files, no larger than 10MB each.'),
        ),
      );
      return;
    }
    setState(() => _documentCount = result.files.length);
  }

  Future<void> _save() async {
    setState(() => _selectedSection = 0);
    await Future<void>.delayed(Duration.zero);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendor details are ready to save.')),
    );
  }

  void _cancel() => Navigator.of(context).maybePop();
}
