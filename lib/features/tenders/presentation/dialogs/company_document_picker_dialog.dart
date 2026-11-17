import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/company_document_item.dart';
import '../../providers/company_document_providers.dart';

/// A modal dialog that lets the user select one or more documents
/// from the Company Vault without leaving the current screen.
///
/// Features context-aware filtering:
/// - ITR: Start Year -> End Year range filter
/// - PF/ESI/GST Challans: Month-wise calendar range filter + Missing Month flag
/// - PF/ESI/GST Certificates: Issue/Start Date range + Expiry status filter
/// - Experience Certificates: Project Code filter
/// - Licences / Registrations / Vendor Auth: Expiry status filter
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

  // ITR Year Range Filter
  int? _itrStartYear;
  int? _itrEndYear;

  // Challan Month Range Filter
  DateTime? _challanStartMonth;
  DateTime? _challanEndMonth;

  // Certificate Date Range Filter (PF / ESI / GST Certs)
  DateTime? _certStartDate;
  DateTime? _certEndDate;

  // Experience Certificate Project Code Filter
  String _projectCodeSearch = '';

  // Expiry Status Filter (ALL, EXPIRING_SOON, EXPIRED, VALID)
  String _expiryStatus = 'ALL';

  bool get _isChallanType =>
      _filterType == CompanyDocType.pfChallan ||
      _filterType == CompanyDocType.esiChallan ||
      _filterType == CompanyDocType.gstChallan;

  bool get _isCertType =>
      _filterType == CompanyDocType.pfCertificate ||
      _filterType == CompanyDocType.esiCertificate ||
      _filterType == CompanyDocType.gstCertificate;

  bool get _isExpiryPrimaryType =>
      _filterType == CompanyDocType.license ||
      _filterType == CompanyDocType.vendorAuth ||
      _filterType == CompanyDocType.registration;

  void _onTypeChanged(CompanyDocType? newType) {
    setState(() {
      _filterType = newType;
    });
  }

  void _clearSecondaryFilters() {
    setState(() {
      _itrStartYear = null;
      _itrEndYear = null;
      _challanStartMonth = null;
      _challanEndMonth = null;
      _certStartDate = null;
      _certEndDate = null;
      _projectCodeSearch = '';
      _expiryStatus = 'ALL';
    });
  }

  int? _extractYear(String? fy) {
    if (fy == null || fy.trim().isEmpty) return null;
    final match = RegExp(r'(\d{4})').firstMatch(fy);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  int? _extractMonthIndex(String? my, DateTime createdAt) {
    if (my != null && my.contains('-')) {
      final parts = my.split('-');
      if (parts.length >= 2) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null) {
          return y * 12 + m;
        }
      }
    }
    return createdAt.year * 12 + createdAt.month;
  }

  /// Computes missing YYYY-MM months for the selected challan type
  /// across the chosen month range (or past 6 months if no range is picked).
  List<String> _computeMissingChallanMonths(List<CompanyDocumentItem> all) {
    if (!_isChallanType || _filterType == null) return const [];

    final existing = all
        .where((d) =>
            d.docType == _filterType && (d.monthYear ?? '').trim().isNotEmpty)
        .map((d) => d.monthYear!.trim())
        .toSet();

    final now = DateTime.now();
    final start =
        _challanStartMonth ?? DateTime(now.year, now.month - 5, 1);
    final end = _challanEndMonth ?? DateTime(now.year, now.month, 1);

    final missing = <String>[];
    var cursor = DateTime(start.year, start.month, 1);
    final endBound = DateTime(end.year, end.month, 1);

    // Guard cap to 36 months so huge ranges stay clean
    int guard = 0;
    while (!cursor.isAfter(endBound) && guard < 36) {
      final ym =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
      if (!existing.contains(ym)) {
        missing.add(DateFormat('MMM yyyy').format(cursor));
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
      guard++;
    }
    return missing;
  }

  List<CompanyDocumentItem> _applyFilter(List<CompanyDocumentItem> all) {
    return all.where((item) {
      // 1. Doc Type filter
      if (_filterType != null && item.docType != _filterType) {
        return false;
      }

      // 2. Global Search query
      final q = _search.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matchSearch = item.title.toLowerCase().contains(q) ||
            item.docType.label.toLowerCase().contains(q) ||
            (item.projectCode?.toLowerCase().contains(q) ?? false) ||
            (item.financialYear?.toLowerCase().contains(q) ?? false) ||
            (item.monthYear?.toLowerCase().contains(q) ?? false);
        if (!matchSearch) return false;
      }

      // 3. ITR Year Range Filter
      if (_filterType == CompanyDocType.itr) {
        final itemYear =
            _extractYear(item.financialYear) ?? item.createdAt.year;
        if (_itrStartYear != null && itemYear < _itrStartYear!) return false;
        if (_itrEndYear != null && itemYear > _itrEndYear!) return false;
      }

      // 4. Challan Month Range Filter
      if (_isChallanType) {
        final itemMonthIdx = _extractMonthIndex(item.monthYear, item.createdAt);
        if (itemMonthIdx != null) {
          if (_challanStartMonth != null) {
            final startIdx =
                _challanStartMonth!.year * 12 + _challanStartMonth!.month;
            if (itemMonthIdx < startIdx) return false;
          }
          if (_challanEndMonth != null) {
            final endIdx =
                _challanEndMonth!.year * 12 + _challanEndMonth!.month;
            if (itemMonthIdx > endIdx) return false;
          }
        }
      }

      // 5. PF / ESI / GST Certificate Date Range Filter
      if (_isCertType) {
        final refDate = item.startDate ?? item.createdAt;
        final dayOnly = DateTime(refDate.year, refDate.month, refDate.day);
        if (_certStartDate != null && dayOnly.isBefore(_certStartDate!)) {
          return false;
        }
        if (_certEndDate != null && dayOnly.isAfter(_certEndDate!)) {
          return false;
        }
      }

      // 6. Experience Certificate Project Code
      if (_filterType == CompanyDocType.experienceCertificate &&
          _projectCodeSearch.trim().isNotEmpty) {
        final code = (item.projectCode ?? '').toLowerCase();
        if (!code.contains(_projectCodeSearch.trim().toLowerCase())) {
          return false;
        }
      }

      // 7. Expiry Filter (Licences / Registrations / Vendor Auth + Certs)
      if ((_isExpiryPrimaryType || _isCertType) && _expiryStatus != 'ALL') {
        if (_expiryStatus == 'EXPIRED' && !item.isExpired) return false;
        if (_expiryStatus == 'EXPIRING_SOON' && !item.isExpiringSoon) {
          return false;
        }
        if (_expiryStatus == 'VALID' &&
            (item.isExpired || item.isExpiringSoon)) {
          return false;
        }
      }

      return true;
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

  Future<void> _pickItrYear({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? DateTime(_itrStartYear ?? now.year - 3)
        : DateTime(_itrEndYear ?? now.year);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: DateTime(now.year + 10),
      initialDatePickerMode: DatePickerMode.year,
      helpText: isStart ? 'Select Start Year' : 'Select End Year',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _itrStartYear = picked.year;
          if (_itrEndYear != null && _itrEndYear! < _itrStartYear!) {
            _itrEndYear = _itrStartYear;
          }
        } else {
          _itrEndYear = picked.year;
          if (_itrStartYear != null && _itrStartYear! > _itrEndYear!) {
            _itrStartYear = _itrEndYear;
          }
        }
      });
    }
  }

  Future<void> _pickChallanMonth({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_challanStartMonth ?? DateTime(now.year, 1))
        : (_challanEndMonth ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 5),
      helpText: isStart ? 'Select Start Month' : 'Select End Month',
    );

    if (picked != null) {
      setState(() {
        final monthDate = DateTime(picked.year, picked.month);
        if (isStart) {
          _challanStartMonth = monthDate;
          if (_challanEndMonth != null &&
              _challanEndMonth!.isBefore(_challanStartMonth!)) {
            _challanEndMonth = _challanStartMonth;
          }
        } else {
          _challanEndMonth = monthDate;
          if (_challanStartMonth != null &&
              _challanStartMonth!.isAfter(_challanEndMonth!)) {
            _challanStartMonth = _challanEndMonth;
          }
        }
      });
    }
  }

  Future<void> _pickCertDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_certStartDate ?? DateTime(now.year - 1, now.month, now.day))
        : (_certEndDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
      helpText: isStart ? 'Select From Date' : 'Select To Date',
    );

    if (picked != null) {
      setState(() {
        final dayOnly = DateTime(picked.year, picked.month, picked.day);
        if (isStart) {
          _certStartDate = dayOnly;
          if (_certEndDate != null && _certEndDate!.isBefore(dayOnly)) {
            _certEndDate = dayOnly;
          }
        } else {
          _certEndDate = dayOnly;
          if (_certStartDate != null && _certStartDate!.isAfter(dayOnly)) {
            _certStartDate = dayOnly;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDocs = ref.watch(companyDocumentsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
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
                  hintText: 'Search documents by name, code or year...',
                  hintStyle: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
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

            // ── Row 1: Document Type filter chips ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'All',
                      selected: _filterType == null,
                      onTap: () => _onTypeChanged(null),
                    ),
                    const SizedBox(width: 6),
                    ...CompanyDocType.values.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _filterChip(
                            label: t.label.split('(').first.trim(),
                            selected: _filterType == t,
                            onTap: () => _onTypeChanged(t),
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // ── Row 2: Context-Aware Secondary Filter ────────────
            _buildContextAwareFilterRow(),

            const SizedBox(height: 8),
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
                  final missingMonths = _computeMissingChallanMonths(all);

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    children: [
                      // Missing Challan Month Warning Flag
                      if (missingMonths.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Missing Challan(s): ${missingMonths.join(', ')}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (filtered.isEmpty)
                        Center(
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
                                      : 'No documents match the selected filters.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF9CA3AF)),
                                ),
                                if (_hasActiveSecondaryFilters()) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _clearSecondaryFilters,
                                    child: const Text(
                                      'Reset Secondary Filters',
                                      style: TextStyle(
                                          color: Color(0xFF414A51),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else
                        ...filtered.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _DocumentTile(
                              item: item,
                              isSelected: _selectedIds.contains(item.id),
                              onToggle: () => _toggle(item),
                            ),
                          ),
                        ),
                    ],
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

  bool _hasActiveSecondaryFilters() {
    return _itrStartYear != null ||
        _itrEndYear != null ||
        _challanStartMonth != null ||
        _challanEndMonth != null ||
        _certStartDate != null ||
        _certEndDate != null ||
        _projectCodeSearch.isNotEmpty ||
        _expiryStatus != 'ALL';
  }

  Widget _buildContextAwareFilterRow() {
    // 1. ITR -> Year Range Filter (Start Year -> End Year)
    if (_filterType == CompanyDocType.itr) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded,
                size: 16, color: Color(0xFF414A51)),
            const SizedBox(width: 6),
            const Text(
              'Year Range:',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51)),
            ),
            const SizedBox(width: 8),
            _pickerButton(
              label: _itrStartYear != null ? '$_itrStartYear' : 'Start Year',
              onTap: () => _pickItrYear(isStart: true),
              hasValue: _itrStartYear != null,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('to',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
            ),
            _pickerButton(
              label: _itrEndYear != null ? '$_itrEndYear' : 'End Year',
              onTap: () => _pickItrYear(isStart: false),
              hasValue: _itrEndYear != null,
            ),
            const Spacer(),
            if (_itrStartYear != null || _itrEndYear != null)
              IconButton(
                tooltip: 'Clear Year Filter',
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF718096)),
                onPressed: () {
                  setState(() {
                    _itrStartYear = null;
                    _itrEndYear = null;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    }

    // 2. PF, ESI, GST Challans -> Month-Wise Range Filter (Calendar)
    if (_isChallanType) {
      final df = DateFormat('MMM yyyy');
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 16, color: Color(0xFF414A51)),
            const SizedBox(width: 6),
            const Text(
              'Month Range:',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51)),
            ),
            const SizedBox(width: 8),
            _pickerButton(
              label: _challanStartMonth != null
                  ? df.format(_challanStartMonth!)
                  : 'Start Month',
              onTap: () => _pickChallanMonth(isStart: true),
              hasValue: _challanStartMonth != null,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('to',
                  style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
            ),
            _pickerButton(
              label: _challanEndMonth != null
                  ? df.format(_challanEndMonth!)
                  : 'End Month',
              onTap: () => _pickChallanMonth(isStart: false),
              hasValue: _challanEndMonth != null,
            ),
            const Spacer(),
            if (_challanStartMonth != null || _challanEndMonth != null)
              IconButton(
                tooltip: 'Clear Month Filter',
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF718096)),
                onPressed: () {
                  setState(() {
                    _challanStartMonth = null;
                    _challanEndMonth = null;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    }

    // 3. PF / ESI / GST Registration Certificates -> Issue Date Range + Expiry Status
    if (_isCertType) {
      final df = DateFormat('dd MMM yyyy');
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            const Icon(Icons.verified_outlined,
                size: 15, color: Color(0xFF414A51)),
            const Text(
              'Date:',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51)),
            ),
            _pickerButton(
              label: _certStartDate != null
                  ? df.format(_certStartDate!)
                  : 'From Date',
              onTap: () => _pickCertDate(isStart: true),
              hasValue: _certStartDate != null,
            ),
            const Text('to',
                style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
            _pickerButton(
              label: _certEndDate != null
                  ? df.format(_certEndDate!)
                  : 'To Date',
              onTap: () => _pickCertDate(isStart: false),
              hasValue: _certEndDate != null,
            ),
            const SizedBox(width: 4),
            _expiryChip(label: 'All', value: 'ALL'),
            _expiryChip(label: 'Expiring', value: 'EXPIRING_SOON'),
            _expiryChip(label: 'Expired', value: 'EXPIRED'),
            if (_certStartDate != null ||
                _certEndDate != null ||
                _expiryStatus != 'ALL')
              InkWell(
                onTap: () {
                  setState(() {
                    _certStartDate = null;
                    _certEndDate = null;
                    _expiryStatus = 'ALL';
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF718096)),
                ),
              ),
          ],
        ),
      );
    }

    // 4. Experience Certificates -> Project Code Filter
    if (_filterType == CompanyDocType.experienceCertificate) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined,
                size: 16, color: Color(0xFF414A51)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Filter by Project Code (e.g. PRJ-2024)...',
                  hintStyle:
                      TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(() => _projectCodeSearch = v),
              ),
            ),
            if (_projectCodeSearch.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF718096)),
                onPressed: () => setState(() => _projectCodeSearch = ''),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    }

    // 5. Licences / Registrations / Vendor Auth -> Expiry Status Filter
    if (_isExpiryPrimaryType) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                size: 16, color: Color(0xFF414A51)),
            const SizedBox(width: 6),
            const Text(
              'Expiry:',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF414A51)),
            ),
            const SizedBox(width: 8),
            _expiryChip(label: 'All', value: 'ALL'),
            const SizedBox(width: 4),
            _expiryChip(label: 'Expiring Soon', value: 'EXPIRING_SOON'),
            const SizedBox(width: 4),
            _expiryChip(label: 'Expired', value: 'EXPIRED'),
            const SizedBox(width: 4),
            _expiryChip(label: 'Active', value: 'VALID'),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _pickerButton({
    required String label,
    required VoidCallback onTap,
    required bool hasValue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasValue
              ? const Color(0xFF9CC70A).withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasValue
                ? const Color(0xFF9CC70A)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                color: hasValue
                    ? const Color(0xFF414A51)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.calendar_today_rounded,
              size: 11,
              color: hasValue
                  ? const Color(0xFF414A51)
                  : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiryChip({required String label, required String value}) {
    final selected = _expiryStatus == value;
    return InkWell(
      onTap: () => setState(() => _expiryStatus = value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF414A51) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                selected ? const Color(0xFF414A51) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
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
            color:
                selected ? const Color(0xFF9CC70A) : const Color(0xFFE5E7EB),
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
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return 'IMG';
    }
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
    final df = DateFormat('dd-MM-yyyy');
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
            color:
                isSelected ? const Color(0xFF9CC70A) : const Color(0xFFE5E7EB),
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF414A51).withValues(alpha: 0.08),
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
                      if (_sizeLabel.isNotEmpty)
                        Text(
                          _sizeLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      if (item.financialYear != null)
                        Text(
                          'FY ${item.financialYear}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF414A51)),
                        ),
                      if (item.monthYear != null)
                        Text(
                          item.monthYear!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF414A51)),
                        ),
                      if (item.projectCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.projectCode!,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7)),
                          ),
                        ),
                      if (item.startDate != null)
                        Text(
                          'Start: ${df.format(item.startDate!)}',
                          style: const TextStyle(
                              fontSize: 10.5, color: Color(0xFF6B7280)),
                        ),
                      if (item.expiryDate != null)
                        Text(
                          'Exp: ${df.format(item.expiryDate!)}',
                          style: const TextStyle(
                              fontSize: 10.5, color: Color(0xFF6B7280)),
                        ),
                      if (item.isExpired)
                        const Text('EXPIRED',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444)))
                      else if (item.isExpiringSoon)
                        Text(
                          'EXPIRES IN ${item.daysUntilExpiry}D',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706)),
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
                color:
                    isSelected ? const Color(0xFF9CC70A) : Colors.transparent,
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
