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
import '../../vendors/domain/vendor.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../domain/books_repository.dart';
import '../invoice_voice/domain/invoice_voice_parameters.dart';
import '../invoice_voice/providers/invoice_voice_providers.dart';
import '../providers/books_providers.dart';
import 'widgets/sales_order_form.dart';

import 'item_details_screen.dart';

class NewItemPage extends ConsumerStatefulWidget {
  const NewItemPage({this.initialItem, super.key});
  final BookItem? initialItem;
  @override
  ConsumerState<NewItemPage> createState() => _NewItemState();
}

class _PartFormState {
  _PartFormState({int slNo = 1}) : slNo = slNo;

  int slNo;
  final partName = TextEditingController();
  final partNo = TextEditingController();
  final partImage = TextEditingController();
  final partPdf = TextEditingController();
  final rmGrade = TextEditingController();
  final rmSize = TextEditingController();
  final rmWeight = TextEditingController();
  final fgWeight = TextEditingController();
  final quantity = TextEditingController(text: '1');
  bool hasProcessFlow = false;
  final List<_OperationFormState> operations = [];

  void dispose() {
    partName.dispose();
    partNo.dispose();
    partImage.dispose();
    partPdf.dispose();
    rmGrade.dispose();
    rmSize.dispose();
    rmWeight.dispose();
    fgWeight.dispose();
    quantity.dispose();
    for (final op in operations) {
      op.dispose();
    }
  }
}

class _OperationFormState {
  _OperationFormState({int operationNumber = 1}) : operationNumber = operationNumber;

  int operationNumber;
  final operationName = TextEditingController();
  final machine = TextEditingController();
  final duration = TextEditingController();
  String remarks = 'Inhouse';
  final vendor = TextEditingController();

  void dispose() {
    operationName.dispose();
    machine.dispose();
    duration.dispose();
    vendor.dispose();
  }
}

class _NewItemState extends ConsumerState<NewItemPage> {
  final name = TextEditingController();
  final hsnCode = TextEditingController();
  final costPrice = TextEditingController();
  final rate = TextEditingController();
  final reportingTags = TextEditingController();
  final product = TextEditingController();
  final productName = TextEditingController();
  final masterSerialNo = TextEditingController();
  final partNo = TextEditingController();
  final drawingFile = TextEditingController();
  final assemblyImage = TextEditingController();

  bool saving = false;
  String itemType = 'Sales and Purchase Items';
  String taxPreference = 'Taxable';
  String intraStateTaxRate = 'GST18 (18 %)';
  String interStateTaxRate = 'IGST18 (18 %)';
  String purchaseAccount = 'Cost of Goods Sold';
  String salesAccount = 'Sales';

  final List<_PartFormState> parts = [];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      name.text = item.name;
      hsnCode.text = item.hsnCode;
      costPrice.text = item.costPrice > 0 ? item.costPrice.toString() : '';
      rate.text = item.rate > 0 ? item.rate.toString() : '';
      if (_itemTypeOptions.contains(item.type)) itemType = item.type;
      if (_taxPreferenceOptions.contains(item.taxPreference)) taxPreference = item.taxPreference;
      if (_intraStateTaxOptions.contains(item.intraStateTaxRate)) intraStateTaxRate = item.intraStateTaxRate;
      if (_interStateTaxOptions.contains(item.interStateTaxRate)) interStateTaxRate = item.interStateTaxRate;
      if (item.purchaseAccount.isNotEmpty) purchaseAccount = item.purchaseAccount;
      if (item.salesAccount.isNotEmpty) salesAccount = item.salesAccount;
      reportingTags.text = item.reportingTags;
      product.text = item.product;
      productName.text = item.productName;
      masterSerialNo.text = item.masterSerialNo;
      partNo.text = item.partNo;
      drawingFile.text = item.drawingFileName;
      assemblyImage.text = item.assemblyImagePath;

      for (final p in item.parts) {
        final pf = _PartFormState(slNo: p.slNo);
        pf.partName.text = p.partName;
        pf.partNo.text = p.partNo;
        pf.partImage.text = p.partImage;
        pf.partPdf.text = p.partPdf;
        pf.rmGrade.text = p.rmGrade;
        pf.rmSize.text = p.rmSize;
        pf.rmWeight.text = p.rmWeight > 0 ? p.rmWeight.toString() : '';
        pf.fgWeight.text = p.fgWeight > 0 ? p.fgWeight.toString() : '';
        pf.quantity.text = p.quantity.toString();
        pf.hasProcessFlow = p.hasProcessFlow;
        for (final op in p.operations) {
          final of = _OperationFormState(operationNumber: op.operationNumber);
          of.operationName.text = op.operationName;
          of.machine.text = op.machine;
          of.duration.text = op.duration;
          of.remarks = op.remarks;
          of.vendor.text = op.vendor ?? '';
          pf.operations.add(of);
        }
        parts.add(pf);
      }
    }
  }

  static const _itemTypeOptions = [
    'Sales and Purchase Items',
    'Goods',
    'Service',
  ];

  static const _taxPreferenceOptions = [
    'Taxable',
    'Non-Taxable',
  ];

  static const _intraStateTaxOptions = [
    'GST0 (0 %)',
    'GST5 (5 %)',
    'GST12 (12 %)',
    'GST18 (18 %)',
    'GST28 (28 %)',
  ];

  static const _interStateTaxOptions = [
    'IGST0 (0 %)',
    'IGST5 (5 %)',
    'IGST12 (12 %)',
    'IGST18 (18 %)',
    'IGST28 (28 %)',
  ];

  static const _salesAccountOptions = [
    'Sales',
    'Domestic Sales',
    'Wholesale Sales',
    'Retail Sales',
    'Export Sales',
    'Service Revenue',
    'Other Sales',
  ];

  static const _purchaseAccountOptions = [
    'Cost of Goods Sold',
    'Material Cost',
    'Product Cost',
    'Purchase Cost',
    'Raw Material Cost',
    'Direct Labour Cost',
    'Other Direct Cost',
  ];

  static const _operationRemarksOptions = [
    'Inhouse',
    'Outsourcing',
  ];

  @override
  void dispose() {
    name.dispose();
    hsnCode.dispose();
    costPrice.dispose();
    rate.dispose();
    reportingTags.dispose();
    product.dispose();
    productName.dispose();
    masterSerialNo.dispose();
    partNo.dispose();
    drawingFile.dispose();
    assemblyImage.dispose();
    for (final p in parts) {
      p.dispose();
    }
    super.dispose();
  }

  void _addPart() {
    setState(() {
      parts.add(_PartFormState(slNo: parts.length + 1));
    });
  }

  void _removePart(int index) {
    setState(() {
      final removed = parts.removeAt(index);
      removed.dispose();
      for (var i = 0; i < parts.length; i++) {
        parts[i].slNo = i + 1;
      }
    });
  }

  void _addOperation(_PartFormState partState) {
    setState(() {
      partState.operations.add(
        _OperationFormState(operationNumber: partState.operations.length + 1),
      );
    });
  }

  void _removeOperation(_PartFormState partState, int opIndex) {
    setState(() {
      final removed = partState.operations.removeAt(opIndex);
      removed.dispose();
      for (var i = 0; i < partState.operations.length; i++) {
        partState.operations[i].operationNumber = i + 1;
      }
    });
  }

  Widget _buildImageUploadField({
    required TextEditingController controller,
    required String label,
    required String folderName,
  }) {
    final hasImage = controller.text.trim().isNotEmpty;
    final isNetworkUrl = controller.text.startsWith('http://') || controller.text.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: hasImage
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF9CC70A), size: 20)
                : null,
            suffixIcon: hasImage
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => controller.clear()),
                    tooltip: 'Clear image',
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  if (file.bytes != null) {
                    final uploadedUrl = await ref.read(booksRepositoryProvider).uploadItemImage(
                      bytes: file.bytes!,
                      fileName: file.name,
                      folderName: folderName,
                    );
                    setState(() => controller.text = uploadedUrl);
                  } else {
                    setState(() => controller.text = file.name);
                  }
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image picker not supported in this environment.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.image),
            label: const Text('Browse Image'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: controller.text.startsWith('data:')
                        ? (Uri.parse(controller.text).data != null
                            ? Image.memory(
                                Uri.parse(controller.text).data!.contentAsBytes(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 22, color: Colors.grey),
                              )
                            : const Icon(Icons.image_outlined, size: 22, color: Colors.grey))
                        : (isNetworkUrl
                            ? Image.network(
                                controller.text,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 22, color: Colors.grey),
                              )
                            : (controller.text.startsWith('assets/')
                                ? Image.asset(controller.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, size: 22, color: Colors.grey))
                                : const Icon(Icons.image_outlined, size: 22, color: Colors.grey))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done, size: 16, color: Color(0xFF9CC70A)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Uploaded to Firebase Storage ($folderName)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF9CC70A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPdfUploadField({
    required TextEditingController controller,
    required String label,
    String folderName = 'Drawing Images',
  }) {
    final hasFile = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: hasFile
                ? const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20)
                : null,
            suffixIcon: hasFile
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => controller.clear()),
                    tooltip: 'Clear file',
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  if (file.bytes != null) {
                    final uploadedUrl = await ref.read(booksRepositoryProvider).uploadItemImage(
                      bytes: file.bytes!,
                      fileName: file.name,
                      folderName: folderName,
                    );
                    setState(() => controller.text = uploadedUrl);
                  } else {
                    setState(() => controller.text = file.name);
                  }
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File picker not supported in this environment.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Browse PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (hasFile) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Color(0xFF9CC70A)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Uploaded to Firebase Storage ($folderName)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF9CC70A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.initialItem != null ? 'Edit Item' : 'New Item',
      saveLabel: 'Save',
      saving: saving,
      onSave: save,
      showAppBar: false,
      maxWidth: 1120,
      children: [
        // Section A — Basic & Tax Details
        const SectionTitle('Section A — Basic & Tax Details'),
        Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
              return Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field(name, 'Item Name / Assembly Name*'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: itemType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Item Type*'),
                      items: _itemTypeOptions
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => itemType = val ?? _itemTypeOptions.first),
                    ),
                    const SizedBox(height: 14),
                    field(hsnCode, 'HSN Code'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: taxPreference,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tax Preference*'),
                      items: _taxPreferenceOptions
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) => setState(() => taxPreference = val ?? 'Taxable'),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: intraStateTaxRate,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Intra-State Tax Rate*'),
                      items: _intraStateTaxOptions
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) => setState(() => intraStateTaxRate = val ?? _intraStateTaxOptions[3]),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: interStateTaxRate,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Inter-State Tax Rate*'),
                      items: _interStateTaxOptions
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) => setState(() => interStateTaxRate = val ?? _interStateTaxOptions[3]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Section B — Pricing & Accounts
        const SectionTitle('Section B — Pricing & Accounts'),
        Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
              return Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field(costPrice, 'Cost Price*', prefix: 'INR', number: true),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: purchaseAccount,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Purchase Account*'),
                      items: _purchaseAccountOptions
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (val) => setState(() => purchaseAccount = val ?? 'Cost of Goods Sold'),
                    ),
                    const SizedBox(height: 14),
                    field(rate, 'Selling Price*', prefix: 'INR', number: true),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: salesAccount,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Sales Account*'),
                      items: _salesAccountOptions
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (val) => setState(() => salesAccount = val ?? 'Sales'),
                    ),
                    const SizedBox(height: 14),
                    field(reportingTags, 'Reporting Tags'),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Section C — Product & Engineering Details
        const SectionTitle('Section C — Product & Engineering Details'),
        Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
              return Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field(product, 'Product*'),
                    const SizedBox(height: 14),
                    field(productName, 'Product Name*'),
                    const SizedBox(height: 14),
                    field(masterSerialNo, 'Master Serial No.*'),
                    const SizedBox(height: 14),
                    field(partNo, 'Part No.*'),
                    const SizedBox(height: 14),
                    _buildPdfUploadField(
                      controller: drawingFile,
                      label: 'Drawing File Upload (PDF)',
                    ),
                    const SizedBox(height: 14),
                    _buildImageUploadField(
                      controller: assemblyImage,
                      label: 'Assembly Diagram Image',
                      folderName: 'Drawing Images',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Section D — Raw Materials & Parts (BOM Builder)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const SectionTitle('Raw Materials & Parts — BOM Builder'),
            FilledButton.icon(
              onPressed: _addPart,
              icon: const Icon(Icons.add),
              label: const Text('Add Raw Material / Part'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (parts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No parts added yet. Click "+ Add Raw Material / Part" to add parts for BOM.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        for (var i = 0; i < parts.length; i++) ...[
          _buildPartCard(parts[i], i),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildPartCard(_PartFormState partState, int index) {
    return Card(
      elevation: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final cardPadding = isMobile ? 12.0 : 20.0;
          return Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Part #${partState.slNo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removePart(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Remove Part',
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (isMobile) ...[
                  TextFormField(
                    initialValue: '${partState.slNo}',
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Sl. No.'),
                  ),
                  const SizedBox(height: 14),
                  field(partState.partName, 'Part Name*'),
                  const SizedBox(height: 14),
                  field(partState.partNo, 'Part No.*'),
                ] else ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: '${partState.slNo}',
                          enabled: false,
                          decoration: const InputDecoration(labelText: 'Sl. No.'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: field(partState.partName, 'Part Name*')),
                      const SizedBox(width: 12),
                      Expanded(child: field(partState.partNo, 'Part No.*')),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _buildImageUploadField(
                  controller: partState.partImage,
                  label: 'Part Image',
                  folderName: 'Raw Material Images',
                ),
                const SizedBox(height: 14),
                _buildPdfUploadField(
                  controller: partState.partPdf,
                  label: 'Choose Part Drawing / Spec (PDF)',
                  folderName: 'Raw Material Drawings',
                ),
                const SizedBox(height: 14),
                if (isMobile) ...[
                  field(partState.rmGrade, 'RM Grade'),
                  const SizedBox(height: 14),
                  field(partState.rmSize, 'RM Size'),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: field(partState.rmGrade, 'RM Grade')),
                      const SizedBox(width: 12),
                      Expanded(child: field(partState.rmSize, 'RM Size')),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (isMobile) ...[
                  field(partState.rmWeight, 'RM Weight (kg)', number: true),
                  const SizedBox(height: 14),
                  field(partState.fgWeight, 'FG Weight (kg)', number: true),
                  const SizedBox(height: 14),
                  field(partState.quantity, 'Quantity*', number: true),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: field(partState.rmWeight, 'RM Weight (kg)', number: true)),
                      const SizedBox(width: 12),
                      Expanded(child: field(partState.fgWeight, 'FG Weight (kg)', number: true)),
                      const SizedBox(width: 12),
                      Expanded(child: field(partState.quantity, 'Quantity*', number: true)),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Has Process Flow?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Enable to add process-flow manufacturing operations'),
                  value: partState.hasProcessFlow,
                  onChanged: (val) {
                    setState(() {
                      partState.hasProcessFlow = val;
                      if (val && partState.operations.isEmpty) {
                        partState.operations.add(_OperationFormState(operationNumber: 1));
                      }
                    });
                  },
                ),
                if (partState.hasProcessFlow) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Process Flow Operations for ${partState.partName.text.isEmpty ? 'Part #${partState.slNo}' : partState.partName.text}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addOperation(partState),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Operation'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var j = 0; j < partState.operations.length; j++)
                    _buildOperationCard(partState, partState.operations[j], j),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperationCard(_PartFormState partState, _OperationFormState opState, int opIndex) {
    final isOutsourcing = opState.remarks == 'Outsourcing';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Operation #${opState.operationNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              IconButton(
                onPressed: () => _removeOperation(partState, opIndex),
                icon: const Icon(Icons.close, size: 20, color: Colors.red),
                tooltip: 'Remove Operation',
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, opConstraints) {
              final isMobile = opConstraints.maxWidth < 500;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field(opState.operationName, 'Operation Name*'),
                    const SizedBox(height: 12),
                    field(opState.machine, 'Machine*'),
                    const SizedBox(height: 12),
                    field(opState.duration, 'Duration* (e.g. 45 mins)'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: opState.remarks,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type / Remarks*'),
                      items: _operationRemarksOptions
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          opState.remarks = val ?? 'Inhouse';
                        });
                      },
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: field(opState.operationName, 'Operation Name*')),
                      const SizedBox(width: 12),
                      Expanded(child: field(opState.machine, 'Machine*')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: field(opState.duration, 'Duration* (e.g. 45 mins)')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: opState.remarks,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Type / Remarks*'),
                          items: _operationRemarksOptions
                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              opState.remarks = val ?? 'Inhouse';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          field(
            opState.vendor,
            'Vendor${isOutsourcing ? '*' : ' (Optional for Inhouse)'}',
          ),
        ],
      ),
    );
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Item Name / Assembly Name.')),
      );
      return;
    }
    if (costPrice.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Cost Price.')),
      );
      return;
    }
    if (rate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Selling Price.')),
      );
      return;
    }
    if (product.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Product.')),
      );
      return;
    }
    if (productName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Product Name.')),
      );
      return;
    }
    if (masterSerialNo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Master Serial No.')),
      );
      return;
    }
    if (partNo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Part No.')),
      );
      return;
    }

    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (p.partName.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter Part Name for Part #${i + 1}.')),
        );
        return;
      }
      if (p.partNo.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter Part No. for Part #${i + 1}.')),
        );
        return;
      }
      if (p.hasProcessFlow) {
        for (var j = 0; j < p.operations.length; j++) {
          final op = p.operations[j];
          if (op.operationName.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Operation Name for Part #${i + 1}, Operation #${j + 1}.')),
            );
            return;
          }
          if (op.machine.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Machine for Part #${i + 1}, Operation #${j + 1}.')),
            );
            return;
          }
          if (op.duration.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Duration for Part #${i + 1}, Operation #${j + 1}.')),
            );
            return;
          }
          if (op.remarks == 'Outsourcing' && op.vendor.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please enter Vendor for Outsourcing Operation #${j + 1} on Part #${i + 1}.')),
            );
            return;
          }
        }
      }
    }

    setState(() => saving = true);
    try {
      final itemParts = parts.map((p) => ItemPart(
        slNo: p.slNo,
        partName: p.partName.text.trim(),
        partNo: p.partNo.text.trim(),
        partImage: p.partImage.text.trim(),
        partPdf: p.partPdf.text.trim(),
        rmGrade: p.rmGrade.text.trim(),
        rmSize: p.rmSize.text.trim(),
        rmWeight: double.tryParse(p.rmWeight.text.trim()) ?? 0,
        fgWeight: double.tryParse(p.fgWeight.text.trim()) ?? 0,
        quantity: double.tryParse(p.quantity.text.trim()) ?? 1,
        hasProcessFlow: p.hasProcessFlow,
        operations: p.hasProcessFlow ? p.operations.map((op) => ItemPartOperation(
          operationNumber: op.operationNumber,
          operationName: op.operationName.text.trim(),
          machine: op.machine.text.trim(),
          duration: op.duration.text.trim(),
          remarks: op.remarks,
          vendor: op.remarks == 'Outsourcing' ? op.vendor.text.trim() : null,
        )).toList() : const [],
      )).toList();

      if (widget.initialItem != null) {
        await ref.read(booksRepositoryProvider).updateItem(
          id: widget.initialItem!.id,
          name: name.text.trim(),
          type: itemType,
          hsnCode: hsnCode.text.trim(),
          taxPreference: taxPreference,
          intraStateTaxRate: intraStateTaxRate,
          interStateTaxRate: interStateTaxRate,
          costPrice: double.tryParse(costPrice.text.trim()) ?? 0,
          purchaseAccount: purchaseAccount,
          rate: double.tryParse(rate.text.trim()) ?? 0,
          salesAccount: salesAccount,
          reportingTags: reportingTags.text.trim(),
          product: product.text.trim(),
          productName: productName.text.trim(),
          masterSerialNo: masterSerialNo.text.trim(),
          partNo: partNo.text.trim(),
          drawingFileName: drawingFile.text.trim(),
          assemblyImagePath: assemblyImage.text.trim(),
          parts: itemParts,
        );
        ref.invalidate(itemsProvider);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully.')),
          );
        }
      } else {
        final newItem = await ref.read(booksRepositoryProvider).addItem(
          name: name.text.trim(),
          type: itemType,
          hsnCode: hsnCode.text.trim(),
          taxPreference: taxPreference,
          intraStateTaxRate: intraStateTaxRate,
          interStateTaxRate: interStateTaxRate,
          costPrice: double.tryParse(costPrice.text.trim()) ?? 0,
          purchaseAccount: purchaseAccount,
          rate: double.tryParse(rate.text.trim()) ?? 0,
          salesAccount: salesAccount,
          reportingTags: reportingTags.text.trim(),
          product: product.text.trim(),
          productName: productName.text.trim(),
          masterSerialNo: masterSerialNo.text.trim(),
          partNo: partNo.text.trim(),
          drawingFileName: drawingFile.text.trim(),
          assemblyImagePath: assemblyImage.text.trim(),
          parts: itemParts,
        );
        ref.invalidate(itemsProvider);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ItemDetailsScreen(item: newItem),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
  final bool _wakePhraseDetected = false;
  final bool _voiceFinishing = false;
  bool _voiceSessionActive = false;
  final bool _voiceRestarting = false;
  String _voiceTranscript = '';
  final int _liveVoiceParseGeneration = 0;
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
      while (invoiceItems.length < itemOffset + values.items.length) {
        invoiceItems.add(_InvoiceItemInput());
      }
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
    this.showAppBar = true,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final double maxWidth;
  final String saveLabel;
  final bool showLeading;
  final bool showAppBar;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.canvas, AppColors.canvas],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            if (showAppBar)
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    if (showLeading)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Back',
                      ),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final gutter = isMobile ? 12.0 : AppLayout.gutter(constraints.maxWidth);
                  final cardPadding = isMobile ? 12.0 : 20.0;
                  return FadeSlideIn(
                    child: ResponsiveContent(
                      maxWidth: maxWidth,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 20),
                        children: [
                          GlassPanel(
                            padding: EdgeInsets.all(cardPadding),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final save = ElevatedButton(
                    onPressed: saving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      saving ? 'Saving...' : saveLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                  final cancel = OutlinedButton(
                    onPressed: saving ? null : () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [save, const SizedBox(height: 8), cancel],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: save),
                      const SizedBox(width: 10),
                      Expanded(child: cancel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
