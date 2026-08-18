import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/vendors/domain/vendor.dart';
import '../../features/vendors/providers/vendor_providers.dart';

class NewVendorForm extends ConsumerStatefulWidget {
  const NewVendorForm({super.key, this.vendorToEdit});

  final Vendor? vendorToEdit;

  @override
  ConsumerState<NewVendorForm> createState() => _NewVendorFormState();
}

class _NewVendorFormState extends ConsumerState<NewVendorForm> {
  final _formKey = GlobalKey<FormState>();
  final _vendorCodeKey = GlobalKey<FormFieldState<String>>();
  final _displayNameKey = GlobalKey<FormFieldState<String>>();
  final _gstTreatmentKey = GlobalKey<FormFieldState<String>>();
  final _sourceOfSupplyKey = GlobalKey<FormFieldState<String>>();

  final _vendorCodeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _workPhoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _panController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  // Address Controllers
  final _addrLine1Controller = TextEditingController();
  final _addrLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _pinCodeController = TextEditingController();

  // Bank Controllers
  final _bankNameController = TextEditingController();
  final _accHolderController = TextEditingController();
  final _accNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _branchController = TextEditingController();

  // Remarks Controller
  final _remarksController = TextEditingController();

  // Contact Person Add Controllers
  final _cFirstNameController = TextEditingController();
  final _cLastNameController = TextEditingController();
  final _cDesignationController = TextEditingController();
  final _cDepartmentController = TextEditingController();
  final _cEmailController = TextEditingController();
  final _cPhoneController = TextEditingController();
  final _cMobileController = TextEditingController();

  String? _salutation;
  String _status = 'Active';
  String? _gstTreatment = 'Registered Business - Regular';
  String? _sourceOfSupply = 'Tamil Nadu';
  String _currency = 'INR - Indian Rupee';
  String _paymentTerms = 'Due on Receipt';
  String? _tds;
  String _accountType = 'Current';
  String? _cSalutation;
  bool _cIsPrimary = false;

  bool _isMsmeRegistered = false;
  bool _showBanner = true;
  bool _showMoreDetails = false;
  bool _saving = false;
  int _selectedSection = 0;

  final List<VendorContactPerson> _contactPersons = [];
  final List<String> _documentPaths = [];

  static const _sections = <String>[
    'Other Details',
    'Address',
    'Contact Persons',
    'Bank Details',
    'Remarks',
  ];

  static const _statuses = <String>[
    'Active',
    'Inactive',
    'Blocked',
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
  void initState() {
    super.initState();
    if (widget.vendorToEdit != null) {
      final v = widget.vendorToEdit!;
      _vendorCodeController.text = v.vendorCode;
      _displayNameController.text = v.displayName;
      _companyNameController.text = v.companyName;
      _salutation = v.salutation.isNotEmpty ? v.salutation : null;
      _firstNameController.text = v.firstName;
      _lastNameController.text = v.lastName;
      _emailController.text = v.email;
      _workPhoneController.text = v.workPhone;
      _mobileController.text = v.mobile;
      _status = v.status;
      _gstTreatment = v.gstTreatment.isNotEmpty ? v.gstTreatment : 'Registered Business - Regular';
      _sourceOfSupply = v.sourceOfSupply.isNotEmpty ? v.sourceOfSupply : 'Tamil Nadu';
      _panController.text = v.pan;
      _isMsmeRegistered = v.msmeRegistered;
      _currency = v.currency.isNotEmpty ? v.currency : 'INR - Indian Rupee';
      _openingBalanceController.text = v.openingBalance > 0 ? v.openingBalance.toString() : '';
      _paymentTerms = v.paymentTerms.isNotEmpty ? v.paymentTerms : 'Due on Receipt';
      _tds = v.tds;
      _remarksController.text = v.remarks;

      if (v.primaryAddress != null) {
        _addrLine1Controller.text = v.primaryAddress!.addressLine1;
        _addrLine2Controller.text = v.primaryAddress!.addressLine2;
        _cityController.text = v.primaryAddress!.city;
        _stateController.text = v.primaryAddress!.state;
        _countryController.text = v.primaryAddress!.country.isNotEmpty ? v.primaryAddress!.country : 'India';
        _pinCodeController.text = v.primaryAddress!.pinCode;
      }

      if (v.bankAccounts.isNotEmpty) {
        final b = v.bankAccounts.first;
        _bankNameController.text = b.bankName;
        _accHolderController.text = b.accountHolderName;
        _accNumberController.text = b.accountNumber;
        _ifscController.text = b.ifscCode;
        _branchController.text = b.branch;
        if (b.accountType.isNotEmpty) _accountType = b.accountType;
      }

      _contactPersons.addAll(v.contactPersons);
      _documentPaths.addAll(v.documentPaths);
    } else {
      _loadNextVendorCode();
    }
  }

  Future<void> _loadNextVendorCode() async {
    final nextCode = await ref.read(vendorRepositoryProvider).generateNextVendorCode();
    if (mounted && _vendorCodeController.text.isEmpty) {
      setState(() {
        _vendorCodeController.text = nextCode;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _vendorCodeController,
      _firstNameController,
      _lastNameController,
      _companyNameController,
      _displayNameController,
      _emailController,
      _workPhoneController,
      _mobileController,
      _panController,
      _openingBalanceController,
      _addrLine1Controller,
      _addrLine2Controller,
      _cityController,
      _stateController,
      _countryController,
      _pinCodeController,
      _bankNameController,
      _accHolderController,
      _accNumberController,
      _ifscController,
      _branchController,
      _remarksController,
      _cFirstNameController,
      _cLastNameController,
      _cDesignationController,
      _cDepartmentController,
      _cEmailController,
      _cPhoneController,
      _cMobileController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                        _sectionTitle('Basic Vendor Details'),
                        const SizedBox(height: 16),
                        _buildBasicDetails(isTablet),
                        const SizedBox(height: 28),
                        _sectionTitle(_sections[_selectedSection]),
                        const SizedBox(height: 12),
                        _buildSectionSelector(),
                        const SizedBox(height: 20),
                        _buildSelectedSectionContent(isTablet),
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
                          : const Text('Save Vendor'),
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

  Widget _buildBasicDetails(bool isTablet) {
    final nameFields = <Widget>[
      _dropdown(
        label: 'Salutation',
        value: _salutation,
        items: const ['Mr.', 'Mrs.', 'Ms.', 'Dr.'],
        onChanged: (value) => setState(() => _salutation = value),
      ),
      _textField(controller: _firstNameController, label: 'First Name'),
      _textField(controller: _lastNameController, label: 'Last Name'),
    ];

    return Column(
      children: [
        _responsiveRow(
          [
            _textField(
              key: _vendorCodeKey,
              controller: _vendorCodeController,
              label: 'Vendor Code',
              required: true,
              validator: _required('Vendor Code'),
            ),
            _dropdown(
              label: 'Status',
              value: _status,
              items: _statuses,
              onChanged: (val) => setState(() => _status = val ?? 'Active'),
            ),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _textField(
          key: _displayNameKey,
          controller: _displayNameController,
          label: 'Display Name',
          required: true,
          validator: _required('Display Name'),
        ),
        const SizedBox(height: 16),
        _textField(controller: _companyNameController, label: 'Company Name'),
        const SizedBox(height: 16),
        _responsiveRow(nameFields, isTablet),
        const SizedBox(height: 16),
        _textField(
          controller: _emailController,
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
            _phoneField(_workPhoneController, 'Work Phone'),
            _phoneField(_mobileController, 'Mobile'),
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

  Widget _buildSelectedSectionContent(bool isTablet) {
    switch (_selectedSection) {
      case 0:
        return _buildOtherDetails(isTablet);
      case 1:
        return _buildAddressSection(isTablet);
      case 2:
        return _buildContactPersonsSection(isTablet);
      case 3:
        return _buildBankDetailsSection(isTablet);
      case 4:
        return _buildRemarksSection();
      default:
        return const SizedBox.shrink();
    }
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
        _textField(controller: _panController, label: 'PAN'),
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
              controller: _openingBalanceController,
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

  Widget _buildAddressSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary Address',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _addrLine1Controller,
          label: 'Address Line 1',
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _addrLine2Controller,
          label: 'Address Line 2',
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _textField(controller: _cityController, label: 'City'),
            _dropdown(
              label: 'State',
              value: _stateController.text.isNotEmpty ? _stateController.text : null,
              items: _states,
              onChanged: (val) => setState(() => _stateController.text = val ?? ''),
            ),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _textField(controller: _countryController, label: 'Country'),
            _textField(
              controller: _pinCodeController,
              label: 'PIN Code',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
          isTablet,
        ),
      ],
    );
  }

  Widget _buildContactPersonsSection(bool isTablet) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_contactPersons.isNotEmpty) ...[
          Text('Saved Contacts', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _contactPersons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = _contactPersons[index];
              return Card(
                child: ListTile(
                  title: Text('${c.salutation} ${c.fullName}'.trim()),
                  subtitle: Text(
                    '${c.designation} ${c.department.isNotEmpty ? '• ${c.department}' : ''}\nPhone: ${c.phone.isNotEmpty ? c.phone : c.mobile} | Email: ${c.email}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isPrimary)
                        Chip(
                          label: const Text('Primary'),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => setState(() => _contactPersons.removeAt(index)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(height: 32),
        ],
        Text('Add Contact Person', style: theme.textTheme.titleSmall),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _dropdown(
              label: 'Salutation',
              value: _cSalutation,
              items: const ['Mr.', 'Mrs.', 'Ms.', 'Dr.'],
              onChanged: (val) => setState(() => _cSalutation = val),
            ),
            _textField(controller: _cFirstNameController, label: 'First Name'),
            _textField(controller: _cLastNameController, label: 'Last Name'),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _textField(controller: _cDesignationController, label: 'Designation'),
            _textField(controller: _cDepartmentController, label: 'Department'),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _cEmailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _phoneField(_cPhoneController, 'Phone'),
            _phoneField(_cMobileController, 'Mobile'),
          ],
          isTablet,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Primary Contact'),
          value: _cIsPrimary,
          onChanged: (val) => setState(() => _cIsPrimary = val),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addContactPerson,
          icon: const Icon(Icons.add),
          label: const Text('Add Contact Person'),
        ),
      ],
    );
  }

  void _addContactPerson() {
    if (_cFirstNameController.text.trim().isEmpty && _cLastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter contact person name.')),
      );
      return;
    }

    final newContact = VendorContactPerson(
      salutation: _cSalutation ?? '',
      firstName: _cFirstNameController.text.trim(),
      lastName: _cLastNameController.text.trim(),
      designation: _cDesignationController.text.trim(),
      department: _cDepartmentController.text.trim(),
      email: _cEmailController.text.trim(),
      phone: _cPhoneController.text.trim(),
      mobile: _cMobileController.text.trim(),
      isPrimary: _cIsPrimary,
    );

    setState(() {
      _contactPersons.add(newContact);
      _cFirstNameController.clear();
      _cLastNameController.clear();
      _cDesignationController.clear();
      _cDepartmentController.clear();
      _cEmailController.clear();
      _cPhoneController.clear();
      _cMobileController.clear();
      _cSalutation = null;
      _cIsPrimary = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact person added.')),
    );
  }

  Widget _buildBankDetailsSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Account Information (Optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _textField(controller: _bankNameController, label: 'Bank Name'),
        const SizedBox(height: 16),
        _textField(controller: _accHolderController, label: 'Account Holder Name'),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _textField(
              controller: _accNumberController,
              label: 'Account Number',
              keyboardType: TextInputType.number,
            ),
            _textField(controller: _ifscController, label: 'IFSC Code'),
          ],
          isTablet,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          [
            _textField(controller: _branchController, label: 'Branch'),
            _dropdown(
              label: 'Account Type',
              value: _accountType,
              items: const ['Current', 'Savings', 'CC/OD'],
              onChanged: (val) => setState(() => _accountType = val ?? 'Current'),
            ),
          ],
          isTablet,
        ),
      ],
    );
  }

  Widget _buildRemarksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remarks & Internal Notes',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _remarksController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add internal notes or instructions regarding this vendor...',
            border: OutlineInputBorder(),
          ),
        ),
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
              _documentPaths.isEmpty
                  ? 'Upload Files'
                  : '${_documentPaths.length} file(s) selected',
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
    setState(() {
      _documentPaths.clear();
      _documentPaths.addAll(result.files.map((f) => f.path ?? f.name));
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(vendorRepositoryProvider);

      VendorAddress? address;
      if (_addrLine1Controller.text.isNotEmpty || _cityController.text.isNotEmpty) {
        address = VendorAddress(
          addressLine1: _addrLine1Controller.text.trim(),
          addressLine2: _addrLine2Controller.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          country: _countryController.text.trim(),
          pinCode: _pinCodeController.text.trim(),
        );
      }

      final bankAccounts = <VendorBankAccount>[];
      if (_bankNameController.text.isNotEmpty || _accNumberController.text.isNotEmpty) {
        bankAccounts.add(VendorBankAccount(
          bankName: _bankNameController.text.trim(),
          accountHolderName: _accHolderController.text.trim(),
          accountNumber: _accNumberController.text.trim(),
          ifscCode: _ifscController.text.trim(),
          branch: _branchController.text.trim(),
          accountType: _accountType,
        ));
      }

      final opBal = double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;

      final vendor = Vendor(
        id: widget.vendorToEdit?.id ?? 0,
        vendorCode: _vendorCodeController.text.trim(),
        displayName: _displayNameController.text.trim(),
        companyName: _companyNameController.text.trim(),
        salutation: _salutation ?? '',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        workPhone: _workPhoneController.text.trim(),
        mobile: _mobileController.text.trim(),
        gstTreatment: _gstTreatment ?? 'Registered Business - Regular',
        sourceOfSupply: _sourceOfSupply ?? 'Tamil Nadu',
        pan: _panController.text.trim(),
        msmeRegistered: _isMsmeRegistered,
        currency: _currency,
        openingBalance: opBal,
        paymentTerms: _paymentTerms,
        tds: _tds,
        status: _status,
        remarks: _remarksController.text.trim(),
        primaryAddress: address,
        contactPersons: _contactPersons,
        bankAccounts: bankAccounts,
        documentPaths: _documentPaths,
      );

      if (widget.vendorToEdit != null) {
        await repo.updateVendor(vendor);
      } else {
        await repo.createVendor(vendor);
      }

      ref.refresh(vendorsProvider);
      ref.refresh(activeVendorsProvider);

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.vendorToEdit != null
                ? 'Vendor updated successfully.'
                : 'Vendor saved successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving vendor: $e')),
      );
    }
  }

  void _cancel() => Navigator.of(context).maybePop();
}
