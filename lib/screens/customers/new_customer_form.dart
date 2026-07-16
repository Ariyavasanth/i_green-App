import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../models/customer.dart';
import '../../providers/customer_providers.dart';
import '../../widgets/customers/customer_form_fields.dart';

class NewCustomerForm extends ConsumerStatefulWidget {
  const NewCustomerForm({super.key});
  @override ConsumerState<NewCustomerForm> createState() => _NewCustomerFormState();
}

class _NewCustomerFormState extends ConsumerState<NewCustomerForm> with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  late final TabController tabs;
  CustomerType type = CustomerType.business;
  TaxPreference taxPreference = TaxPreference.taxable;
  String salutation = 'Mr.', language = 'English', gstTreatment = '', supply = '', currency = 'INR', paymentTerms = 'Due on Receipt';
  bool portal = false, saving = false;
  final first = TextEditingController(), last = TextEditingController(), company = TextEditingController(), display = TextEditingController(), email = TextEditingController(), workPhone = TextEditingController(), mobile = TextEditingController(), pan = TextEditingController(), gstin = TextEditingController(), opening = TextEditingController(), remarks = TextEditingController();
  final billing = _AddressControllers(), shipping = _AddressControllers();
  final contacts = <_ContactControllers>[];
  final customFields = <_CustomFieldControllers>[];
  final tags = <String>{};
  List<PlatformFile> documents = [];

  static const states = ['Andaman and Nicobar Islands', 'Andhra Pradesh', 'Delhi', 'Gujarat', 'Karnataka', 'Kerala', 'Maharashtra', 'Rajasthan', 'Tamil Nadu', 'Telangana', 'Uttar Pradesh', 'West Bengal'];
  static const gstOptions = ['Registered Business - Regular', 'Registered Business - Composition', 'Unregistered Business', 'Consumer', 'Overseas'];

  @override void initState() { super.initState(); tabs = TabController(length: 6, vsync: this); }
  @override void dispose() { tabs.dispose(); for (final c in [first,last,company,display,email,workPhone,mobile,pan,gstin,opening,remarks]) { c.dispose(); } billing.dispose(); shipping.dispose(); for (final c in contacts) { c.dispose(); } for (final c in customFields) { c.dispose(); } super.dispose(); }

  @override Widget build(BuildContext context) => ColoredBox(color: AppColors.canvas, child: Column(children: [
    AppBar(title: const Text('New Customer')),
    Expanded(child: LayoutBuilder(builder: (_, box) { final gutter = AppLayout.gutter(box.maxWidth); return ResponsiveContent(maxWidth: 1200, child: Form(key: formKey, child: ListView(padding: EdgeInsets.all(gutter), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Customer Type', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(children: CustomerType.values.map((v) => SizedBox(width: 150, child: RadioListTile<CustomerType>(contentPadding: EdgeInsets.zero, title: Text(v == CustomerType.business ? 'Business' : 'Individual'), value: v, groupValue: type, onChanged: (x) => setState(() => type = x!)))).toList()),
        const Divider(), const SizedBox(height: 10),
        ResponsiveFieldGrid(children: [
          DropdownButtonFormField<String>(initialValue: salutation, decoration: const InputDecoration(labelText: 'Salutation', border: OutlineInputBorder()), items: ['Mr.','Mrs.','Ms.','Dr.'].map(_item).toList(), onChanged: (v) => salutation = v!),
          CustomerTextField(controller: first, label: 'First Name'), CustomerTextField(controller: last, label: 'Last Name'),
          CustomerTextField(controller: company, label: 'Company Name'), CustomerTextField(controller: display, label: 'Display Name', required: true),
          CustomerTextField(controller: email, label: 'Email Address', keyboardType: TextInputType.emailAddress, validator: (v) { if (v == null || v.isEmpty) return null; return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v) ? null : 'Enter a valid email'; }),
          PhoneField(controller: workPhone, label: 'Work Phone'), PhoneField(controller: mobile, label: 'Mobile'),
          DropdownButtonFormField<String>(initialValue: language, decoration: const InputDecoration(labelText: 'Customer Language', border: OutlineInputBorder()), items: ['English','Hindi','Tamil','Telugu','Kannada','Malayalam'].map(_item).toList(), onChanged: (v) => language = v!),
        ]),
      ]))), const SizedBox(height: 16),
      Card(child: Column(children: [TabBar(controller: tabs, isScrollable: true, tabs: const [Tab(text: 'Other Details'),Tab(text: 'Address'),Tab(text: 'Contact Persons'),Tab(text: 'Custom Fields'),Tab(text: 'Reporting Tags'),Tab(text: 'Remarks')]), SizedBox(height: box.maxWidth < 600 ? 700 : 560, child: TabBarView(controller: tabs, children: [_otherDetails(), _addresses(), _contactPersons(), _customFields(), _reportingTags(), _remarks()]))])),
      const SizedBox(height: 16), Row(children: [FilledButton(onPressed: saving ? null : _save, child: saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')), const SizedBox(width: 12), OutlinedButton(onPressed: saving ? null : () => context.pop(), child: const Text('Cancel'))]),
    ]))); })),
  ]));

  DropdownMenuItem<String> _item(String value) => DropdownMenuItem(value: value, child: Text(value));
  Widget _pad(Widget child) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: child);

  Widget _otherDetails() => _pad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    ResponsiveFieldGrid(children: [
      DropdownButtonFormField<String>(value: gstTreatment.isEmpty ? null : gstTreatment, decoration: const InputDecoration(labelText: 'GST Treatment *', border: OutlineInputBorder()), items: gstOptions.map(_item).toList(), validator: (v) => v == null ? 'GST Treatment is required' : null, onChanged: (v) => setState(() => gstTreatment = v!)),
      DropdownButtonFormField<String>(value: supply.isEmpty ? null : supply, decoration: const InputDecoration(labelText: 'Place of Supply *', border: OutlineInputBorder()), items: states.map(_item).toList(), validator: (v) => v == null ? 'Place of Supply is required' : null, onChanged: (v) => setState(() => supply = v!)),
      CustomerTextField(controller: gstin, label: 'GSTIN'), CustomerTextField(controller: pan, label: 'PAN'),
      DropdownButtonFormField<String>(initialValue: currency, decoration: const InputDecoration(labelText: 'Currency', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'INR', child: Text('INR - Indian Rupee'))], onChanged: (v) => currency = v!),
      CustomerTextField(controller: opening, label: 'Opening Balance', keyboardType: TextInputType.number),
      DropdownButtonFormField<String>(initialValue: paymentTerms, decoration: const InputDecoration(labelText: 'Payment Terms', border: OutlineInputBorder()), items: ['Due on Receipt','Net 15','Net 30','Net 45','Net 60'].map(_item).toList(), onChanged: (v) => paymentTerms = v!),
    ]), const SizedBox(height: 12),
    Wrap(spacing: 12, children: [const Text('Tax Preference:'), ChoiceChip(label: const Text('Taxable'), selected: taxPreference == TaxPreference.taxable, onSelected: (_) => setState(() => taxPreference = TaxPreference.taxable)), ChoiceChip(label: const Text('Tax Exempt'), selected: taxPreference == TaxPreference.taxExempt, onSelected: (_) => setState(() => taxPreference = TaxPreference.taxExempt))]),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: portal, title: const Text('Enable Customer Portal'), onChanged: (v) => setState(() => portal = v!)),
    Wrap(spacing: 12, runSpacing: 8, children: [OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GST portal prefill will be available soon.'))), icon: const Icon(Icons.auto_fix_high), label: const Text('Prefill from GST portal')), OutlinedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.upload_file), label: Text(documents.isEmpty ? 'Upload Documents' : '${documents.length} document(s)'))]),
    const Padding(padding: EdgeInsets.only(top: 8), child: Text('Up to 10 files, maximum 10 MB each.', style: TextStyle(color: AppColors.textSecondary))),
  ]));

  Widget _addresses() => _pad(Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Billing Address', style: TextStyle(fontWeight: FontWeight.w700)), TextButton.icon(onPressed: () => setState(() => shipping.copyFrom(billing)), icon: const Icon(Icons.copy), label: const Text('Copy to shipping'))]), _addressGrid(billing), const Divider(height: 32), const Align(alignment: Alignment.centerLeft, child: Text('Shipping Address', style: TextStyle(fontWeight: FontWeight.w700))), const SizedBox(height: 12), _addressGrid(shipping)]));
  Widget _addressGrid(_AddressControllers a) => ResponsiveFieldGrid(children: [CustomerTextField(controller: a.attention, label: 'Attention'), CustomerTextField(controller: a.country, label: 'Country/Region'), CustomerTextField(controller: a.address1, label: 'Address Line 1'), CustomerTextField(controller: a.address2, label: 'Address Line 2'), CustomerTextField(controller: a.city, label: 'City'), CustomerTextField(controller: a.state, label: 'State'), CustomerTextField(controller: a.pin, label: 'Pin Code', keyboardType: TextInputType.number), PhoneField(controller: a.phone, label: 'Phone'), CustomerTextField(controller: a.fax, label: 'Fax Number')]);

  Widget _contactPersons() => _pad(Column(children: [for (var i=0;i<contacts.length;i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Expanded(child: CustomerTextField(controller: contacts[i].name, label: 'Contact name')), const SizedBox(width: 8), Expanded(child: CustomerTextField(controller: contacts[i].email, label: 'Email')), IconButton(onPressed: () => setState(() { contacts.removeAt(i).dispose(); }), icon: const Icon(Icons.delete_outline))])), Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => contacts.add(_ContactControllers())), icon: const Icon(Icons.add), label: const Text('Add Contact Person')))]));
  Widget _customFields() => _pad(Column(children: [for (var i=0;i<customFields.length;i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Expanded(child: CustomerTextField(controller: customFields[i].name, label: 'Field name')), const SizedBox(width: 8), Expanded(child: CustomerTextField(controller: customFields[i].value, label: 'Value')), IconButton(onPressed: () => setState(() { customFields.removeAt(i).dispose(); }), icon: const Icon(Icons.delete_outline))])), Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => customFields.add(_CustomFieldControllers())), icon: const Icon(Icons.add), label: const Text('Add Custom Field')))]));
  Widget _reportingTags() => _pad(Wrap(spacing: 10, children: ['Retail','Wholesale','Enterprise','Priority','Export'].map((tag) => FilterChip(label: Text(tag), selected: tags.contains(tag), onSelected: (v) => setState(() => v ? tags.add(tag) : tags.remove(tag)))).toList()));
  Widget _remarks() => _pad(CustomerTextField(controller: remarks, label: 'Internal notes', maxLines: 8));

  Future<void> _pickFiles() async {
    // file_picker 11 exposes picking as a static API on FilePicker.
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    final files = result.files;
    if (files.length > 10 || files.any((f) => f.size > 10 * 1024 * 1024)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select no more than 10 files, each under 10 MB.'),
        ));
      }
      return;
    }
    setState(() => documents = files);
  }
  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) { tabs.animateTo(0); return; }
    setState(() => saving = true);
    try {
      final customer = Customer(type: type, salutation: salutation, firstName: first.text.trim(), lastName: last.text.trim(), displayName: display.text.trim(), companyName: company.text.trim(), email: email.text.trim(), workPhone: workPhone.text.trim(), mobile: mobile.text.trim(), language: language, gstTreatment: gstTreatment, placeOfSupply: supply, pan: pan.text.trim(), gstin: gstin.text.trim(), taxPreference: taxPreference, currency: currency, openingBalance: double.tryParse(opening.text) ?? 0, paymentTerms: paymentTerms, portalEnabled: portal, billingAddress: billing.value, shippingAddress: shipping.value, contacts: contacts.map((c) => c.value).toList(), customFields: {for (final f in customFields) if (f.name.text.trim().isNotEmpty) f.name.text.trim(): f.value.text.trim()}, reportingTags: tags.toList(), remarks: remarks.text.trim(), documentNames: documents.map((f) => f.name).toList());
      await ref.read(customerRepositoryProvider).createCustomer(customer); ref.invalidate(activeCustomersProvider); if (mounted) context.go('/customers');
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save customer: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
}

class _AddressControllers { final attention=TextEditingController(), country=TextEditingController(text:'India'), address1=TextEditingController(), address2=TextEditingController(), city=TextEditingController(), state=TextEditingController(), pin=TextEditingController(), phone=TextEditingController(), fax=TextEditingController(); CustomerAddress get value => CustomerAddress(attention: attention.text, country: country.text, address1: address1.text, address2: address2.text, city: city.text, state: state.text, pinCode: pin.text, phone: phone.text, fax: fax.text); void copyFrom(_AddressControllers a) { attention.text=a.attention.text; country.text=a.country.text; address1.text=a.address1.text; address2.text=a.address2.text; city.text=a.city.text; state.text=a.state.text; pin.text=a.pin.text; phone.text=a.phone.text; fax.text=a.fax.text; } void dispose() { for(final c in [attention,country,address1,address2,city,state,pin,phone,fax]) { c.dispose(); } } }
class _ContactControllers { final name=TextEditingController(), email=TextEditingController(); CustomerContact get value => CustomerContact(firstName:name.text,email:email.text); void dispose(){name.dispose();email.dispose();} }
class _CustomFieldControllers { final name=TextEditingController(), value=TextEditingController(); void dispose(){name.dispose();value.dispose();} }
