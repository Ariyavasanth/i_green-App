import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/organization.dart';
import '../../providers/organization_providers.dart';
import '../../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../../employee/services/offer_letter_save_io.dart';

class OrganizationFormDialog extends ConsumerStatefulWidget {
  const OrganizationFormDialog({this.organization, super.key});

  final Organization? organization;

  static Future<bool?> show(BuildContext context, {Organization? organization}) {
    final isMobile = MediaQuery.of(context).size.width < 640 || MediaQuery.of(context).size.height < 700;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: OrganizationFormDialog(organization: organization),
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: OrganizationFormDialog(organization: organization),
        ),
      );
    }
  }

  @override
  ConsumerState<OrganizationFormDialog> createState() => _OrganizationFormDialogState();
}

class _ContactItemState {
  _ContactItemState({required String label, required String number})
      : labelController = TextEditingController(text: label),
        numberController = TextEditingController(text: number);

  final TextEditingController labelController;
  final TextEditingController numberController;

  void dispose() {
    labelController.dispose();
    numberController.dispose();
  }
}

class _DirectorItemState {
  _DirectorItemState({required String name, required String din})
      : nameController = TextEditingController(text: name),
        dinController = TextEditingController(text: din);

  final TextEditingController nameController;
  final TextEditingController dinController;

  void dispose() {
    nameController.dispose();
    dinController.dispose();
  }
}

class _DocUploadItem {
  _DocUploadItem({
    required this.title,
    this.existingDoc,
    this.pickedFile,
  });

  final String title;
  OrgDocument? existingDoc;
  PlatformFile? pickedFile;
}

class _OrganizationFormDialogState extends ConsumerState<OrganizationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _industryTypeController;
  final TextEditingController _newBuController = TextEditingController();
  final TextEditingController _newLocController = TextEditingController();
  List<String> _businessUnits = [];
  List<String> _locations = [];
  late final TextEditingController _addressController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;

  // Tax & Legal IDs
  late final TextEditingController _gstController;
  late final TextEditingController _cinController;
  late final TextEditingController _panController;
  late final TextEditingController _tanController;

  // Multiple Contact Numbers
  final List<_ContactItemState> _contacts = [];

  // Directors & DIN
  final List<_DirectorItemState> _directors = [];

  // Statutory Documents
  final Map<String, _DocUploadItem> _statutoryDocs = {
    'Certificate of Incorporation': _DocUploadItem(title: 'Certificate of Incorporation'),
    'Memorandum of Association (MOA)': _DocUploadItem(title: 'Memorandum of Association (MOA)'),
    'Articles of Association (AOA)': _DocUploadItem(title: 'Articles of Association (AOA)'),
  };
  final List<_DocUploadItem> _extraDocs = [];

  bool _isSaving = false;
  String _uploadStatusMessage = '';

  static const List<String> _contactLabels = [
    'Primary Mobile',
    'Secondary Mobile',
    'Landline',
    'Helpdesk / Toll-Free',
    'HR / Admin',
    'Finance / Billing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    _nameController = TextEditingController(text: org?.name ?? '');
    _businessTypeController = TextEditingController(text: org?.businessType.isNotEmpty == true ? org!.businessType : 'Private Limited Company');
    _industryTypeController = TextEditingController(text: org?.industryType ?? '');
    _businessUnits = (org?.businessUnits ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _locations = (org?.locations ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _addressController = TextEditingController(text: org?.address ?? '');
    _pincodeController = TextEditingController(text: org?.pincode ?? '');
    _emailController = TextEditingController(text: org?.emailAddress ?? '');
    _websiteController = TextEditingController(text: org?.website ?? '');

    _gstController = TextEditingController(text: org?.gstNumber.isNotEmpty == true ? org!.gstNumber : (org?.taxId ?? ''));
    _cinController = TextEditingController(text: org?.cinNumber ?? '');
    _panController = TextEditingController(text: org?.panNumber ?? '');
    _tanController = TextEditingController(text: org?.tanNumber ?? '');

    // Initialize contact numbers
    if (org != null && org.contactNumbers.isNotEmpty) {
      for (final c in org.contactNumbers) {
        _contacts.add(_ContactItemState(label: c.label, number: c.number));
      }
    } else if (org != null && org.phoneNumber.isNotEmpty) {
      _contacts.add(_ContactItemState(label: 'Primary Mobile', number: org.phoneNumber));
    } else {
      _contacts.add(_ContactItemState(label: 'Primary Mobile', number: ''));
    }

    // Initialize directors
    if (org != null && org.directors.isNotEmpty) {
      for (final d in org.directors) {
        _directors.add(_DirectorItemState(name: d.name, din: d.din));
      }
    }

    // Initialize existing documents
    if (org != null && org.documents.isNotEmpty) {
      for (final doc in org.documents) {
        if (_statutoryDocs.containsKey(doc.title)) {
          _statutoryDocs[doc.title]!.existingDoc = doc;
        } else if (doc.title == 'Certificate of Incorporation' ||
            doc.title.contains('Incorporation')) {
          _statutoryDocs['Certificate of Incorporation']!.existingDoc = doc;
        } else if (doc.title.contains('MOA') || doc.title.contains('Memorandum')) {
          _statutoryDocs['Memorandum of Association (MOA)']!.existingDoc = doc;
        } else if (doc.title.contains('AOA') || doc.title.contains('Articles')) {
          _statutoryDocs['Articles of Association (AOA)']!.existingDoc = doc;
        } else {
          _extraDocs.add(_DocUploadItem(title: doc.title, existingDoc: doc));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessTypeController.dispose();
    _industryTypeController.dispose();
    _newBuController.dispose();
    _newLocController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _gstController.dispose();
    _cinController.dispose();
    _panController.dispose();
    _tanController.dispose();
    for (final c in _contacts) {
      c.dispose();
    }
    for (final d in _directors) {
      d.dispose();
    }
    super.dispose();
  }

  void _addBusinessUnit([String? value]) {
    final text = (value ?? _newBuController.text).trim();
    if (text.isEmpty) return;
    final items = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final item in items) {
        if (!_businessUnits.contains(item)) {
          _businessUnits.add(item);
        }
      }
      _newBuController.clear();
    });
  }

  void _addLocation([String? value]) {
    final text = (value ?? _newLocController.text).trim();
    if (text.isEmpty) return;
    final items = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final item in items) {
        if (!_locations.contains(item)) {
          _locations.add(item);
        }
      }
      _newLocController.clear();
    });
  }

  Future<void> _pickFileForDoc(_DocUploadItem item) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          item.pickedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _openDocUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document link.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _addCustomDocument() async {
    final titleController = TextEditingController();
    final customTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Statutory Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name *',
            hintText: 'e.g. GST Registration Certificate, MSME, Udyam',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9CC70A), foregroundColor: Colors.white),
            onPressed: () {
              final t = titleController.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (customTitle != null && customTitle.isNotEmpty) {
      final item = _DocUploadItem(title: customTitle);
      setState(() {
        _extraDocs.add(item);
      });
      _pickFileForDoc(item);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newBuController.text.trim().isNotEmpty) {
      _addBusinessUnit();
    }
    if (_newLocController.text.trim().isNotEmpty) {
      _addLocation();
    }

    setState(() {
      _isSaving = true;
      _uploadStatusMessage = 'Saving organization details...';
    });

    try {
      final repo = ref.read(organizationRepositoryProvider);
      final orgId = widget.organization?.id != 0 && widget.organization != null
          ? widget.organization!.id
          : DateTime.now().millisecondsSinceEpoch;

      // Prepare contact numbers
      final contactList = _contacts
          .where((c) => c.numberController.text.trim().isNotEmpty)
          .map((c) => ContactNumber(
                label: c.labelController.text.trim().isNotEmpty ? c.labelController.text.trim() : 'Mobile',
                number: c.numberController.text.trim(),
              ))
          .toList();

      final primaryPhone = contactList.isNotEmpty ? contactList.first.number : '';

      // Prepare directors
      final directorsList = _directors
          .where((d) => d.nameController.text.trim().isNotEmpty || d.dinController.text.trim().isNotEmpty)
          .map((d) => DirectorDetail(
                name: d.nameController.text.trim(),
                din: d.dinController.text.trim(),
              ))
          .toList();

      // Process and upload documents
      final allDocItems = [..._statutoryDocs.values, ..._extraDocs];
      final finalDocs = <OrgDocument>[];

      for (final docItem in allDocItems) {
        if (docItem.pickedFile != null) {
          setState(() {
            _uploadStatusMessage = 'Uploading ${docItem.title}...';
          });
          final uploaded = await repo.uploadDocument(
            orgId: orgId,
            docTitle: docItem.title,
            file: docItem.pickedFile,
          );
          finalDocs.add(uploaded);
        } else if (docItem.existingDoc != null) {
          finalDocs.add(docItem.existingDoc!);
        }
      }

      final org = Organization(
        id: orgId,
        name: _nameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        industryType: _industryTypeController.text.trim(),
        businessUnits: _businessUnits.join(', '),
        locations: _locations.join(', '),
        address: _addressController.text.trim(),
        pincode: _pincodeController.text.trim(),
        phoneNumber: primaryPhone,
        contactNumbers: contactList,
        emailAddress: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        taxId: _gstController.text.trim(),
        gstNumber: _gstController.text.trim(),
        cinNumber: _cinController.text.trim(),
        panNumber: _panController.text.trim(),
        tanNumber: _tanController.text.trim(),
        directors: directorsList,
        documents: finalDocs,
      );

      if (widget.organization == null) {
        await repo.addOrganization(org);
      } else {
        await repo.updateOrganization(org);
      }

      ref.invalidate(organizationsProvider);
      ref.invalidate(departmentsProvider);
      ref.invalidate(allDesignationsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving organization: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.organization != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 640 || screenHeight < 700;
    final isSingleColumn = screenWidth < 600;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isMobile ? 20 : 16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isMobile ? double.infinity : 680,
        height: screenHeight * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle for mobile / sheet view
            if (isMobile)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note : Icons.add_business,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Organization' : 'Add Organization',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const Text(
                          'Configure company details, statutory IDs, directors & documents',
                          style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF667085)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAECF0)),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Basic Organization Info
                    _buildSectionHeader(Icons.business_outlined, 'General Information'),
                    const SizedBox(height: 12),
                    _buildField(
                      label: 'Organization Name *',
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Organization name is required' : null,
                      hint: 'e.g. IGreentec Engg. India Pvt. Ltd.',
                    ),
                    const SizedBox(height: 14),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'Business Type',
                        controller: _businessTypeController,
                        hint: 'e.g. Private Limited Company, LLP, Partnership',
                      ),
                      right: _buildField(
                        label: 'Industry Type',
                        controller: _industryTypeController,
                        hint: 'e.g. Engineering, Manufacturing, IT Services',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildMultiItemField(
                        label: 'Business Unit(s)',
                        controller: _newBuController,
                        items: _businessUnits,
                        onAdd: _addBusinessUnit,
                        onRemove: (item) => setState(() => _businessUnits.remove(item)),
                        isMobile: isSingleColumn,
                        hint: 'e.g. Projects & Services, HDD',
                      ),
                      right: _buildMultiItemField(
                        label: 'Location(s)',
                        controller: _newLocController,
                        items: _locations,
                        onAdd: _addLocation,
                        onRemove: (item) => setState(() => _locations.remove(item)),
                        isMobile: isSingleColumn,
                        hint: 'e.g. Chennai Head Office, Ambattur Plant',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Registered Office Address',
                      controller: _addressController,
                      hint: 'e.g. 557, Mangaldeep Apartments, D Block F1, Ramnagar',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'PIN / Postal Code',
                        controller: _pincodeController,
                        hint: 'e.g. 600058',
                        keyboardType: TextInputType.number,
                      ),
                      right: _buildField(
                        label: 'Official Email Address',
                        controller: _emailController,
                        hint: 'e.g. info@igreentec.example',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Website URL',
                      controller: _websiteController,
                      hint: 'e.g. https://www.igreentec.example',
                    ),

                    const SizedBox(height: 24),
                    // Section 2: Multiple Contact Numbers
                    _buildSectionHeader(
                      Icons.call_outlined,
                      'Contact & Phone Numbers',
                      trailing: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _contacts.add(_ContactItemState(label: 'Secondary Mobile', number: ''));
                          });
                        },
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                        label: const Text('Add Number', style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildContactNumbersList(),

                    const SizedBox(height: 24),
                    // Section 3: Tax & Legal Identification Details
                    _buildSectionHeader(Icons.gavel_outlined, 'Tax & Legal Identification Details'),
                    const SizedBox(height: 12),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'GST / VAT Number',
                        controller: _gstController,
                        hint: 'e.g. 33ABCDE1234F1Z5',
                      ),
                      right: _buildField(
                        label: 'CIN (Corporate Identification No.)',
                        controller: _cinController,
                        hint: 'e.g. U74999TN2020PTC123456',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildResponsiveRow(
                      isSingleColumn: isSingleColumn,
                      left: _buildField(
                        label: 'PAN (Permanent Account Number)',
                        controller: _panController,
                        hint: 'e.g. ABCDE1234F',
                      ),
                      right: _buildField(
                        label: 'TAN (Tax Deduction Account No.)',
                        controller: _tanController,
                        hint: 'e.g. CHNE12345F',
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Section 4: Directors & DIN Details
                    _buildSectionHeader(
                      Icons.people_outline_rounded,
                      'Directors & DIN Details',
                      trailing: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _directors.add(_DirectorItemState(name: '', din: ''));
                          });
                        },
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                        label: const Text('Add Director', style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDirectorsList(),

                    const SizedBox(height: 24),
                    // Section 5: Incorporation & Statutory Document Uploads
                    _buildSectionHeader(
                      Icons.folder_open_outlined,
                      'Incorporation & Statutory Documents',
                      trailing: TextButton.icon(
                        onPressed: _addCustomDocument,
                        icon: const Icon(Icons.upload_file, size: 16, color: AppColors.primary),
                        label: const Text('Add Other Doc', style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentUploadsList(),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Footer Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
            ),
            child: Row(
              children: [
                if (_isSaving)
                  Expanded(
                    child: Text(
                      _uploadStatusMessage,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Organization', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSectionHeader(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF414A51)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildContactNumbersList() {
    if (_contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Row(
          children: [
            const Text('No contact numbers added yet.', style: TextStyle(fontSize: 12.5, color: Color(0xFF667085))),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _contacts.add(_ContactItemState(label: 'Primary Mobile', number: ''))),
              child: const Text('+ Add Number', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _contacts.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _contactLabels.contains(_contacts[i].labelController.text)
                        ? _contacts[i].labelController.text
                        : 'Primary Mobile',
                    isExpanded: true,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: _contactLabels
                        .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _contacts[i].labelController.text = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _contacts[i].numberController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'e.g. +91 44 4567 8900',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Remove',
                  onPressed: () {
                    setState(() {
                      final item = _contacts.removeAt(i);
                      item.dispose();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirectorsList() {
    if (_directors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Row(
          children: [
            const Text('No directors added yet.', style: TextStyle(fontSize: 12.5, color: Color(0xFF667085))),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _directors.add(_DirectorItemState(name: '', din: ''))),
              child: const Text('+ Add Director', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _directors.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _directors[i].nameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Director Name',
                      hintText: 'e.g. John Doe',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _directors[i].dinController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'DIN Number',
                      hintText: 'e.g. 01234567',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Remove Director',
                  onPressed: () {
                    setState(() {
                      final item = _directors.removeAt(i);
                      item.dispose();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentUploadsList() {
    final allItems = [..._statutoryDocs.values, ..._extraDocs];

    return Column(
      children: allItems.map((item) => _buildDocUploadCard(item)).toList(),
    );
  }

  Widget _buildDocUploadCard(_DocUploadItem item) {
    final hasPicked = item.pickedFile != null;
    final hasExisting = item.existingDoc != null && item.existingDoc!.fileUrl.isNotEmpty;
    final fileName = hasPicked
        ? item.pickedFile!.name
        : (hasExisting ? item.existingDoc!.fileName : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (hasPicked || hasExisting) ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (hasPicked || hasExisting) ? const Color(0xFF86EFAC) : const Color(0xFFEAECF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (hasPicked || hasExisting)
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFEAECF0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              (hasPicked || hasExisting) ? Icons.description_rounded : Icons.cloud_upload_outlined,
              size: 20,
              color: (hasPicked || hasExisting) ? const Color(0xFF15803D) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                if (fileName != null)
                  Text(
                    hasPicked ? 'New: $fileName' : fileName,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: hasPicked ? const Color(0xFF15803D) : const Color(0xFF64748B),
                      fontWeight: hasPicked ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text(
                    'No document attached (PDF, JPG, PNG, DOC)',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (hasPicked || hasExisting) ...[
            if (hasExisting && item.existingDoc?.fileUrl.isNotEmpty == true) ...[
              IconButton(
                icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF414A51)),
                tooltip: 'View Document',
                onPressed: () => _openDocUrl(item.existingDoc!.fileUrl),
              ),
              IconButton(
                icon: const Icon(Icons.file_download_outlined, size: 18, color: AppColors.primary),
                tooltip: 'Download Document',
                onPressed: () => downloadFileFromUrl(
                  context: context,
                  url: item.existingDoc!.fileUrl,
                  fileName: item.existingDoc!.fileName.isNotEmpty ? item.existingDoc!.fileName : '${item.title}.pdf',
                  docTitle: item.title,
                ),
              ),
            ],
            TextButton.icon(
              onPressed: () => _pickFileForDoc(item),
              icon: const Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
              label: const Text('Replace', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
              tooltip: 'Remove',
              onPressed: () {
                setState(() {
                  item.pickedFile = null;
                  item.existingDoc = null;
                  if (_extraDocs.contains(item)) {
                    _extraDocs.remove(item);
                  }
                });
              },
            ),
          ] else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF344054),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _pickFileForDoc(item),
              icon: const Icon(Icons.upload_file, size: 15, color: AppColors.primary),
              label: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveRow({
    required bool isSingleColumn,
    required Widget left,
    required Widget right,
  }) {
    if (isSingleColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    String? hint,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
            ),
            if (helperText != null)
              Text(
                helperText,
                style: const TextStyle(fontSize: 11, color: Color(0xFF667085), fontStyle: FontStyle.italic),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiItemField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required VoidCallback onAdd,
    required void Function(String) onRemove,
    required bool isMobile,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onRemove(item),
                      child: const Icon(Icons.close, size: 13, color: AppColors.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
