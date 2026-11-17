import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/company_document_item.dart';
import '../../providers/company_document_providers.dart';
import '../widgets/tender_document_actions.dart';

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

  Future<void> _showDocumentDialog({CompanyDocumentItem? existing}) async {
    final isEdit = existing != null;
    CompanyDocType selectedType = existing?.docType ?? CompanyDocType.itr;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final fyCtrl = TextEditingController(
      text: existing?.financialYear ??
          '${DateTime.now().year - 1}-${DateTime.now().year}',
    );
    final monthCtrl = TextEditingController(
      text: existing?.monthYear ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final projectCodeCtrl =
        TextEditingController(text: existing?.projectCode ?? '');
    final alertDaysCtrl = TextEditingController(
      text: (existing?.alertBeforeDays ?? 30).toString(),
    );
    DateTime? startDate = existing?.startDate;
    DateTime? expiryDate = existing?.expiryDate;
    PlatformFile? pickedFile;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final needsFy = selectedType == CompanyDocType.itr;
          final needsMonth = selectedType == CompanyDocType.pfChallan ||
              selectedType == CompanyDocType.esiChallan ||
              selectedType == CompanyDocType.gstChallan;
          final needsProject =
              selectedType == CompanyDocType.experienceCertificate;
          final isExpiryPrimary = selectedType == CompanyDocType.license ||
              selectedType == CompanyDocType.vendorAuth ||
              selectedType == CompanyDocType.registration;
          final supportsValidityDates = isExpiryPrimary ||
              selectedType == CompanyDocType.pfCertificate ||
              selectedType == CompanyDocType.esiCertificate ||
              selectedType == CompanyDocType.gstCertificate ||
              selectedType == CompanyDocType.experienceCertificate;

          return AlertDialog(
            title: Text(
              isEdit ? 'Edit / Renew Document' : 'Add Company Document',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF414A51),
              ),
            ),
            content: SizedBox(
              width: 460,
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: monthCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Month-Year (YYYY-MM)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Pick Month from Calendar',
                            icon: const Icon(Icons.calendar_month_rounded),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2015),
                                lastDate: DateTime(2040),
                                helpText: 'Select Challan Month',
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  monthCtrl.text =
                                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                          ),
                        ],
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
                    if (supportsValidityDates) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2045),
                                  helpText: 'Select Start / Issue Date',
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    startDate = picked;
                                    if (expiryDate != null &&
                                        expiryDate!.isBefore(picked)) {
                                      expiryDate = null;
                                    }
                                  });
                                }
                              },
                              icon: const Icon(Icons.event_available_rounded,
                                  size: 16),
                              label: Text(
                                startDate == null
                                    ? 'Start Date'
                                    : 'Start: ${DateFormat('dd-MM-yyyy').format(startDate!)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: expiryDate ??
                                      (startDate ?? DateTime.now())
                                          .add(const Duration(days: 365)),
                                  firstDate: startDate ?? DateTime(2000),
                                  lastDate: DateTime(2050),
                                  helpText: 'Select Expiry Date',
                                );
                                if (picked != null) {
                                  setDialogState(() => expiryDate = picked);
                                }
                              },
                              icon: const Icon(Icons.event_busy_rounded,
                                  size: 16),
                              label: Text(
                                expiryDate == null
                                    ? (isExpiryPrimary
                                        ? 'Expiry Date *'
                                        : 'Expiry (Optional)')
                                    : 'Exp: ${DateFormat('dd-MM-yyyy').format(expiryDate!)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (expiryDate != null || isExpiryPrimary) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: alertDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Alert Before Expiry (Days)',
                            helperText:
                                'Notification alert triggers this many days before expiry',
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.notifications_active_outlined),
                          ),
                        ),
                      ],
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
                        pickedFile != null
                            ? pickedFile!.name
                            : (isEdit
                                ? 'Replace File (Current: ${existing.document.name})'
                                : 'Choose File'),
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
                  if (!isEdit && pickedFile == null) return;
                  final parsedAlertDays =
                      int.tryParse(alertDaysCtrl.text.trim()) ?? 30;
                  final safeAlertDays =
                      parsedAlertDays < 1 ? 1 : parsedAlertDays;
                  final finalTitle = titleCtrl.text.trim().isEmpty
                      ? selectedType.label
                      : titleCtrl.text.trim();

                  Navigator.of(ctx).pop();
                  setState(() => _isUploading = true);
                  try {
                    final repo = ref.read(companyDocumentRepositoryProvider);
                    if (isEdit) {
                      await repo.updateDocument(
                        existing: existing,
                        docType: selectedType,
                        title: finalTitle,
                        newFile: pickedFile,
                        financialYear: needsFy ? fyCtrl.text.trim() : null,
                        monthYear: needsMonth ? monthCtrl.text.trim() : null,
                        projectCode:
                            needsProject ? projectCodeCtrl.text.trim() : null,
                        startDate: supportsValidityDates ? startDate : null,
                        expiryDate: supportsValidityDates ? expiryDate : null,
                        alertBeforeDays: safeAlertDays,
                      );
                    } else {
                      await repo.addDocument(
                        docType: selectedType,
                        title: finalTitle,
                        file: pickedFile!,
                        financialYear: needsFy ? fyCtrl.text.trim() : null,
                        monthYear: needsMonth ? monthCtrl.text.trim() : null,
                        projectCode:
                            needsProject ? projectCodeCtrl.text.trim() : null,
                        startDate: supportsValidityDates ? startDate : null,
                        expiryDate: supportsValidityDates ? expiryDate : null,
                        alertBeforeDays: safeAlertDays,
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isUploading = false);
                  }
                },
                child: Text(isEdit ? 'Save Changes' : 'Upload'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF414A51)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/tenders');
            }
          },
        ),
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
                onPressed: () => _showDocumentDialog(),
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
          final missingPf =
              findMissingChallanMonths(docs, CompanyDocType.pfChallan);
          final missingEsi =
              findMissingChallanMonths(docs, CompanyDocType.esiChallan);
          final missingGst =
              findMissingChallanMonths(docs, CompanyDocType.gstChallan);
          final expiring =
              docs.where((d) => d.isExpiringSoon || d.isExpired).toList();

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
                          Text(
                              '• Missing PF Challans: ${missingPf.join(", ")}'),
                        if (missingEsi.isNotEmpty)
                          Text(
                              '• Missing ESI Challans: ${missingEsi.join(", ")}'),
                        if (missingGst.isNotEmpty)
                          Text(
                              '• Missing GST Challans: ${missingGst.join(", ")}'),
                        for (final exp in expiring)
                          Text(
                            exp.isExpired
                                ? '• ${exp.title} (EXPIRED on ${DateFormat("dd-MM-yyyy").format(exp.expiryDate!)})'
                                : '• ${exp.title} (Expires in ${exp.daysUntilExpiry} day(s) on ${DateFormat("dd-MM-yyyy").format(exp.expiryDate!)})',
                            style: TextStyle(
                              color: exp.isExpired
                                  ? Colors.red.shade700
                                  : const Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: doc.isExpired
                            ? Colors.red.shade300
                            : doc.isExpiringSoon
                                ? Colors.amber.shade400
                                : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => TenderDocumentActions.viewDocument(
                        context,
                        doc.document,
                      ),
                      leading: Icon(
                        doc.isExpired
                            ? Icons.warning_amber_rounded
                            : Icons.description_outlined,
                        color: doc.isExpired
                            ? Colors.red
                            : doc.isExpiringSoon
                                ? const Color(0xFFD97706)
                                : const Color(0xFF414A51),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              doc.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.isExpired) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXPIRED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ] else if (doc.isExpiringSoon) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'EXPIRES IN ${doc.daysUntilExpiry}D',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text([
                        doc.docType.label,
                        if (doc.financialYear != null)
                          'FY: ${doc.financialYear}',
                        if (doc.monthYear != null) 'Month: ${doc.monthYear}',
                        if (doc.projectCode != null)
                          'Project: ${doc.projectCode}',
                        if (doc.startDate != null)
                          'Start: ${DateFormat("dd-MM-yyyy").format(doc.startDate!)}',
                        if (doc.expiryDate != null)
                          'Expiry: ${DateFormat("dd-MM-yyyy").format(doc.expiryDate!)} (Alert ${doc.alertBeforeDays}d prior)',
                      ].join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined,
                                color: Color(0xFF414A51)),
                            tooltip: 'View Document',
                            onPressed: () => TenderDocumentActions.viewDocument(
                              context,
                              doc.document,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Color(0xFF414A51)),
                            tooltip: 'Edit / Renew Document',
                            onPressed: () =>
                                _showDocumentDialog(existing: doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Delete Document',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Document'),
                                  content: Text(
                                    'Are you sure you want to delete "${doc.title}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref
                                    .read(companyDocumentRepositoryProvider)
                                    .deleteDocument(doc.id);
                              }
                            },
                          ),
                        ],
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
