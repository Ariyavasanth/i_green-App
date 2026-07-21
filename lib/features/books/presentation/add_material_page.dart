import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../domain/books_repository.dart';
import '../providers/books_providers.dart';
import 'books_forms.dart';

class AddMaterialPage extends ConsumerStatefulWidget {
  const AddMaterialPage({super.key});

  @override
  ConsumerState<AddMaterialPage> createState() => _AddMaterialPageState();
}

class _AddMaterialPageState extends ConsumerState<AddMaterialPage> {
  final formKey = GlobalKey<FormState>();
  final description = TextEditingController();
  final size = TextEditingController();
  final weight = TextEditingController();
  final usedFor = TextEditingController();
  final stockAlert = TextEditingController();
  String sourceType = 'RAW';
  int? vendorId;
  Uint8List? imageBytes;
  String? imageName;
  bool saving = false;

  @override
  void dispose() {
    description.dispose();
    size.dispose();
    weight.dispose();
    usedFor.dispose();
    stockAlert.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: 'ADD MATERIAL',
    saving: saving,
    saveLabel: 'Add Material',
    onSave: _save,
    children: [
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: sourceType,
              decoration: const InputDecoration(labelText: 'Raw or Outsource*'),
              items: const ['RAW', 'OUTSOURCE']
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => sourceType = value ?? sourceType),
            ),
            const SizedBox(height: 14),
            _requiredField(description, 'Description', lines: 3),
            const SizedBox(height: 14),
            _requiredField(size, 'Size'),
            const SizedBox(height: 14),
            _requiredField(weight, 'Weight'),
            const SizedBox(height: 14),
            _requiredField(usedFor, 'Used for'),
            const SizedBox(height: 14),
            _imagePicker(),
            const SizedBox(height: 14),
            TextFormField(
              controller: stockAlert,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stock alert*'),
              validator: (value) {
                final number = double.tryParse(value ?? '');
                return number == null || number < 0 ? 'Enter a valid stock alert' : null;
              },
            ),
            const SizedBox(height: 14),
            ref.watch(vendorsProvider).when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load vendors: $error'),
              data: (vendors) => DropdownButtonFormField<int>(
                initialValue: vendorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vendors*'),
                items: vendors.map((vendor) => DropdownMenuItem(
                  value: vendor.id,
                  child: Text(vendor.name, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (value) => setState(() => vendorId = value),
                validator: (value) => value == null ? 'Select a vendor' : null,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _requiredField(TextEditingController controller, String label, {int lines = 1}) => TextFormField(
    controller: controller,
    maxLines: lines,
    decoration: InputDecoration(labelText: '$label*'),
    validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
  );

  Widget _imagePicker() => InkWell(
    onTap: _pickImage,
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: const InputDecoration(labelText: 'Image', suffixIcon: Icon(Icons.upload_outlined)),
      child: imageBytes == null
          ? const Text('Choose image', style: TextStyle(color: AppColors.textSecondary))
          : Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(imageBytes!, width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(imageName ?? 'Selected image', overflow: TextOverflow.ellipsis)),
              IconButton(
                tooltip: 'Remove image',
                onPressed: () => setState(() { imageBytes = null; imageName = null; }),
                icon: const Icon(Icons.close),
              ),
            ]),
    ),
  );

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file?.bytes != null && mounted) {
      setState(() { imageBytes = file!.bytes; imageName = file.name; });
    }
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false) || vendorId == null) return;
    setState(() => saving = true);
    try {
      await ref.read(booksRepositoryProvider).addMaterial(MaterialDraft(
        sourceType: sourceType,
        description: description.text.trim(),
        size: size.text.trim(),
        weight: weight.text.trim(),
        usedFor: usedFor.text.trim(),
        image: imageBytes,
        stockAlert: double.parse(stockAlert.text),
        vendorId: vendorId!,
      ));
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
