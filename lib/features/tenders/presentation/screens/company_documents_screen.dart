import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/company_document_item.dart';
import '../../providers/company_document_providers.dart';

class CompanyDocumentsScreen extends ConsumerStatefulWidget {
  const CompanyDocumentsScreen({super.key});

  @override
  ConsumerState<CompanyDocumentsScreen> createState() =>
      _CompanyDocumentsScreenState();
}

class _CompanyDocumentsScreenState
    extends ConsumerState<CompanyDocumentsScreen> {
  CompanyDocType? _filterType;
  bool _isUploading = false;

  Future<void> _showAddDocumentDialog() async {
    CompanyDocType selectedType = CompanyDocType.itr;
    final titleCtrl = TextEditingController();
    final fyCtrl = TextEditingController(text: '${DateTime.now().year - 1}-${DateTime.now().year}');
    final monthCtrl = TextEditingController(
      text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final projectCodeCtrl = TextEditingController();
    DateTime? expiryDate;
    PlatformFile? pickedFile;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final needsFy = selectedType == CompanyDocType.itr;
          final needsMonth = selectedType == CompanyDocType.pfChallan ||
              selectedType == CompanyDocType.esiChallan ||
              selectedType == CompanyDocType.gstChallan;
          final needsProject = selectedType == CompanyDocType.experienceCertificate;
          final needsExpiry = selectedType == CompanyDocType.license ||
              selectedType == CompanyDocType.vendorAuth ||
              selectedType == CompanyDocType.registration;

          return AlertDialog(
            title: const Text('Add Company Document'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<CompanyDocType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                        border: OutlineInputBorder(),
                      ),
                      items: CompanyDocType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Document Title / Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (needsFy) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: fyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Financial Year (e.g. 2024-2025)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsMonth) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: monthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Month-Year (YYYY-MM)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsProject) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: projectCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Project Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsExpiry) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2040),
                          );
                          if (picked != null) {
                            setDialogState(() => expiryDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          expiryDate == null
                              ? 'Select Expiry Date'
                              : 'Expires: ${DateFormat('dd-MM-yyyy').format(expiryDate!)}',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.pickFiles(
                          withData: true,
                        );
                        if (res != null && res.files.isNotEmpty) {
                          setDialogState(() => pickedFile = res.files.first);
                        }
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        pickedFile == null
                            ? 'Choose File'
                            : pickedFile!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                ),
                onPressed: () async {
                  if (pickedFile == null) return;
                  Navigator.of(ctx).pop();
                  setState(() => _isUploading = true);
                  try {
                    await ref.read(companyDocumentRepositoryProvider).addDocument(
                          docType: selectedType,
                          title: titleCtrl.text.trim().isEmpty
                              ? selectedType.label
                              : titleCtrl.text.trim(),
                          file: pickedFile!,
                          financialYear: needsFy ? fyCtrl.text.trim() : null,
                          monthYear: needsMonth ? monthCtrl.text.trim() : null,
                          projectCode: needsProject ? projectCodeCtrl.text.trim() : null,
                          expiryDate: needsExpiry ? expiryDate : null,
                        );
                  } finally {
                    if (mounted) setState(() => _isUploading = false);
                  }
                },
                child: const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(companyDocumentsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF414A51),
        elevation: 0,
        title: const Text(
          'Company Document Vault',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                ),
                onPressed: _showAddDocumentDialog,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload Document'),
              ),
            ),
        ],
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (docs) {
          final missingPf = findMissingChallanMonths(docs, CompanyDocType.pfChallan);
          final missingEsi = findMissingChallanMonths(docs, CompanyDocType.esiChallan);
          final missingGst = findMissingChallanMonths(docs, CompanyDocType.gstChallan);
          final expiring = docs.where((d) => d.isExpiringSoon || d.isExpired).toList();

          final filtered = _filterType == null
              ? docs
              : docs.where((d) => d.docType == _filterType).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (missingPf.isNotEmpty ||
                  missingEsi.isNotEmpty ||
                  missingGst.isNotEmpty ||
                  expiring.isNotEmpty)
                Card(
                  color: const Color(0xFFFFFBEB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compliance & Expiry Alerts',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (missingPf.isNotEmpty)
                          Text('• Missing PF Challans: ${missingPf.join(", ")}'),
                        if (missingEsi.isNotEmpty)
                          Text('• Missing ESI Challans: ${missingEsi.join(", ")}'),
                        if (missingGst.isNotEmpty)
                          Text('• Missing GST Challans: ${missingGst.join(", ")}'),
                        for (final exp in expiring)
                          Text(
                            '• ${exp.title} (${exp.isExpired ? "EXPIRED" : "Expiring Soon"}: ${DateFormat("dd-MM-yyyy").format(exp.expiryDate!)})',
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filterType == null,
                    onSelected: (_) => setState(() => _filterType = null),
                  ),
                  ...CompanyDocType.values.map(
                    (t) => ChoiceChip(
                      label: Text(t.label),
                      selected: _filterType == t,
                      onSelected: (_) => setState(() => _filterType = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No documents uploaded in this category yet.'),
                  ),
                )
              else
                ...filtered.map(
                  (doc) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined,
                          color: Color(0xFF414A51)),
                      title: Text(
                        doc.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text([
                        doc.docType.label,
                        if (doc.financialYear != null) 'FY: ${doc.financialYear}',
                        if (doc.monthYear != null) 'Month: ${doc.monthYear}',
                        if (doc.projectCode != null) 'Project: ${doc.projectCode}',
                        if (doc.expiryDate != null)
                          'Expiry: ${DateFormat("dd-MM-yyyy").format(doc.expiryDate!)}',
                      ].join(' • ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => ref
                            .read(companyDocumentRepositoryProvider)
                            .deleteDocument(doc.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

