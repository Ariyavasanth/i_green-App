import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/company_document_item.dart';
import '../../providers/company_document_providers.dart';

/// A modal dialog that lets the user select one or more documents
/// from the Company Vault without leaving the current screen.
///
/// Returns `List<CompanyDocumentItem>` (the selected items) via
/// `Navigator.pop(context, selectedItems)` when the user confirms.
class CompanyDocumentPickerDialog extends ConsumerStatefulWidget {
  const CompanyDocumentPickerDialog({super.key});

  /// Convenience helper to open the dialog and await the result.
  static Future<List<CompanyDocumentItem>?> show(BuildContext context) {
    return showDialog<List<CompanyDocumentItem>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CompanyDocumentPickerDialog(),
    );
  }

  @override
  ConsumerState<CompanyDocumentPickerDialog> createState() =>
      _CompanyDocumentPickerDialogState();
}

class _CompanyDocumentPickerDialogState
    extends ConsumerState<CompanyDocumentPickerDialog> {
  final Set<String> _selectedIds = {};
  String _search = '';
  CompanyDocType? _filterType; // null = All

  List<CompanyDocumentItem> _applyFilter(List<CompanyDocumentItem> all) {
    return all.where((item) {
      final matchType = _filterType == null || item.docType == _filterType;
      final q = _search.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.docType.label.toLowerCase().contains(q) ||
          (item.projectCode?.toLowerCase().contains(q) ?? false) ||
          (item.financialYear?.toLowerCase().contains(q) ?? false);
      return matchType && matchSearch;
    }).toList();
  }

  void _toggle(CompanyDocumentItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _confirm(List<CompanyDocumentItem> all) {
    final selected =
        all.where((item) => _selectedIds.contains(item.id)).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final asyncDocs = ref.watch(companyDocumentsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFE5E8E2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF9CC70A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_shared_outlined,
                        size: 18, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECT FROM COMPANY VAULT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF414A51),
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'Select one or more documents to attach to BQR',
                          style: TextStyle(
                              fontSize: 11.5, color: Color(0xFF718096)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF718096)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),

            // ── Category filter chips ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(label: 'All', selected: _filterType == null,
                        onTap: () => setState(() => _filterType = null)),
                    const SizedBox(width: 6),
                    ...CompanyDocType.values.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _filterChip(
                            label: t.label.split('(').first.trim(),
                            selected: _filterType == t,
                            onTap: () => setState(() => _filterType = t),
                          ),
                        )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE5E8E2)),

            // ── Document list ────────────────────────────────────
            Flexible(
              child: asyncDocs.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: Color(0xFF9CC70A), strokeWidth: 2.5),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load vault: $e',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFFD97706))),
                  ),
                ),
                data: (all) {
                  final filtered = _applyFilter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off_outlined,
                                size: 40,
                                color: const Color(0xFF9CA3AF)
                                    .withValues(alpha: 0.6)),
                            const SizedBox(height: 10),
                            Text(
                              all.isEmpty
                                  ? 'Company Vault is empty.\nUpload documents in Company Vault first.'
                                  : 'No documents match your search.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final isSelected = _selectedIds.contains(item.id);
                      return _DocumentTile(
                        item: item,
                        isSelected: isSelected,
                        onToggle: () => _toggle(item),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E8E2)),

            // ── Footer ───────────────────────────────────────────
            asyncDocs.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (all) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedIds.isEmpty
                          ? 'No documents selected'
                          : '${_selectedIds.length} document(s) selected',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _selectedIds.isEmpty
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF414A51),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel',
                              style: TextStyle(color: Color(0xFF718096))),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _selectedIds.isEmpty
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF9CC70A),
                            foregroundColor: _selectedIds.isEmpty
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF414A51),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _confirm(all),
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: Text(
                            _selectedIds.isEmpty
                                ? 'Attach'
                                : 'Attach (${_selectedIds.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF9CC70A).withValues(alpha: 0.15)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF9CC70A)
                : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? const Color(0xFF414A51)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── Individual document tile ─────────────────────────────────────────────────

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.item,
    required this.isSelected,
    required this.onToggle,
  });

  final CompanyDocumentItem item;
  final bool isSelected;
  final VoidCallback onToggle;

  String get _sizeLabel {
    final bytes = item.document.size;
    if (bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _ext {
    final name = item.document.name.toLowerCase();
    if (name.endsWith('.pdf')) return 'PDF';
    if (name.endsWith('.doc') || name.endsWith('.docx')) return 'DOC';
    if (name.endsWith('.xls') || name.endsWith('.xlsx')) return 'XLS';
    if (name.endsWith('.png') || name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) return 'IMG';
    return 'FILE';
  }

  Color get _extColor {
    switch (_ext) {
      case 'PDF':
        return const Color(0xFFEF4444);
      case 'DOC':
        return const Color(0xFF3B82F6);
      case 'XLS':
        return const Color(0xFF16A34A);
      case 'IMG':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9CC70A).withValues(alpha: 0.08)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9CC70A)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // File type badge
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _extColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _ext,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _extColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Title and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF414A51),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF414A51).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.docType.label.split('(').first.trim(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF414A51)),
                        ),
                      ),
                      if (_sizeLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          _sizeLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                      if (item.financialYear != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'FY ${item.financialYear}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                      if (item.isExpired)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('EXPIRED',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444))),
                        )
                      else if (item.isExpiringSoon)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('EXPIRING SOON',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF59E0B))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF9CC70A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF9CC70A)
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
