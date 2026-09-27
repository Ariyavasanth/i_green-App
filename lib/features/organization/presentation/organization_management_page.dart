import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/organization.dart';
import '../domain/column_preference.dart';
import '../providers/organization_providers.dart';
import '../services/organization_migration_service.dart';
import 'widgets/column_selection_dialog.dart';
import 'widgets/organization_details_dialog.dart';
import 'widgets/organization_form_dialog.dart';
import 'widgets/organization_share_dialog.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';

class OrganizationManagementPage extends ConsumerStatefulWidget {
  const OrganizationManagementPage({super.key});

  @override
  ConsumerState<OrganizationManagementPage> createState() =>
      _OrganizationManagementPageState();
}

class _OrganizationManagementPageState
    extends ConsumerState<OrganizationManagementPage> {
  static const String _tableId = 'organization_management_table';

  static const List<String> _defaultAllColumns = [
    'Organization Name',
    'Status',
    'Business Type',
    'Industry Type',
    'Business Unit(s)',
    'Location(s)',
    'Address',
    'Phone Number',
    'Email Address',
    'Website',
    'GST / VAT Number',
    'CIN Number',
    'PAN Number',
    'TAN Number',
    'Directors / DIN',
    'Documents',
  ];

  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<int> _selectedIds = {};
  Set<String>? _activeVisibleColumns;
  String _selectedBusinessTypeFilter = 'All';
  String _selectedIndustryTypeFilter = 'All';

  Set<String> _getEffectiveVisibleColumns(ColumnPreference? pref) {
    if (_activeVisibleColumns != null) {
      return _activeVisibleColumns!;
    }
    if (pref != null && pref.visibleColumns.isNotEmpty) {
      return pref.visibleColumns.toSet();
    }
    return _defaultAllColumns.toSet();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedBusinessTypeFilter != 'All') count++;
    if (_selectedIndustryTypeFilter != 'All') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationsProvider);
    final prefAsync = ref.watch(columnPreferenceProvider(_tableId));
    final searchQuery = ref.watch(orgSearchQueryProvider);
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildToolbar(context, prefAsync, orgsAsync.valueOrNull ?? [], isMobile),
          _buildActiveFilterChips(),
          const Divider(height: 1, color: Color(0xFFEAECF0)),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF9CC70A),
              onRefresh: () async {
                ref.invalidate(organizationsProvider);
                ref.invalidate(columnPreferenceProvider(_tableId));
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: orgsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Unable to load organizations: $err'),
                ),
                data: (orgs) {
                  final filtered = orgs.where((org) {
                    if (_selectedBusinessTypeFilter != 'All' && org.businessType != _selectedBusinessTypeFilter) {
                      return false;
                    }
                    if (_selectedIndustryTypeFilter != 'All' && org.industryType != _selectedIndustryTypeFilter) {
                      return false;
                    }
                    if (searchQuery.trim().isEmpty) return true;
                    final q = searchQuery.toLowerCase();
                    return org.name.toLowerCase().contains(q) ||
                        org.businessType.toLowerCase().contains(q) ||
                        org.industryType.toLowerCase().contains(q) ||
                        org.address.toLowerCase().contains(q) ||
                        org.pincode.toLowerCase().contains(q) ||
                        org.emailAddress.toLowerCase().contains(q) ||
                        org.phoneNumber.toLowerCase().contains(q) ||
                        org.taxId.toLowerCase().contains(q) ||
                        org.gstNumber.toLowerCase().contains(q) ||
                        org.cinNumber.toLowerCase().contains(q) ||
                        org.panNumber.toLowerCase().contains(q) ||
                        org.tanNumber.toLowerCase().contains(q) ||
                        org.contactNumbers.any((c) => c.number.toLowerCase().contains(q) || c.label.toLowerCase().contains(q)) ||
                        org.directors.any((d) => d.name.toLowerCase().contains(q) || d.din.toLowerCase().contains(q));
                  }).toList();

                  if (filtered.isEmpty) {
                    final bool isFirstTimeSetup = orgs.isEmpty;
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isFirstTimeSetup ? Icons.business_outlined : Icons.search_off_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isFirstTimeSetup
                                  ? 'No Organizations Configured'
                                  : 'No organizations found matching your criteria.',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFirstTimeSetup
                                  ? 'Get started by creating your company profile and business details.'
                                  : 'Try adjusting your search query or filters.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (isFirstTimeSetup) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => OrganizationFormDialog.show(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Organization'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9CC70A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  final pref = prefAsync.valueOrNull;
                  final effectiveSet = _getEffectiveVisibleColumns(pref);
                  final visibleCols = _defaultAllColumns.where((c) => effectiveSet.contains(c)).toList();

                  final totalItems = filtered.length;
                  final totalPages = (totalItems / _rowsPerPage).ceil();
                  final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
                  final startIndex = pageIndex * _rowsPerPage;
                  final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                  final pageItems = filtered.sublist(startIndex, endIndex);

                  return Column(
                    children: [
                      Expanded(
                        child: isMobile
                            ? _buildMobileList(pageItems)
                            : _buildDesktopTable(
                                pageItems,
                                visibleCols,
                                MediaQuery.of(context).size.width,
                              ),
                      ),
                      _buildPaginationBar(
                        totalItems: totalItems,
                        startIndex: startIndex,
                        endIndex: endIndex,
                        currentPage: pageIndex,
                        totalPages: totalPages,
                        isMobile: isMobile,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
    List<Organization> allOrgs,
    bool isMobile,
  ) {
    final searchController = TextEditingController(
      text: ref.read(orgSearchQueryProvider),
    );
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    final pref = prefAsync.valueOrNull;
    final visibleCols = (pref != null && pref.visibleColumns.isNotEmpty)
        ? List<String>.from(pref.visibleColumns)
        : List<String>.from(_defaultAllColumns);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search organizations...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF667085),
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF667085)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF667085)),
                          onPressed: () {
                            ref.read(orgSearchQueryProvider.notifier).state = '';
                            setState(() => _currentPage = 0);
                          },
                        ),
                      InkWell(
                        onTap: () => _openFilterModal(context, allOrgs),
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: _activeFiltersCount > 0
                                    ? AppColors.primary
                                    : const Color(0xFF667085),
                              ),
                            ),
                            if (_activeFiltersCount > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$_activeFiltersCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
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
                onChanged: (val) {
                  ref.read(orgSearchQueryProvider.notifier).state = val;
                  setState(() => _currentPage = 0);
                },
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: const Color(0xFF344054),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                minimumSize: const Size(42, 42),
              ),
              tooltip: 'Data Migration & ID Audit',
              onPressed: () => _openMigrationDialog(context),
              icon: const Icon(Icons.published_with_changes_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            _buildColumnsDropdownButton(context, visibleCols, pref),
          ],
          const SizedBox(width: 8),
          if (isMobile)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(42, 42),
              ),
              tooltip: 'Add Organization',
              onPressed: () => _openAddDialog(context),
              icon: const Icon(Icons.add, size: 20),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openAddDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Organization',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  final ScrollController _horizontalScrollController = ScrollController();
  final LayerLink _columnsLayerLink = LayerLink();
  final GlobalKey _columnsButtonKey = GlobalKey();
  OverlayEntry? _columnsOverlayEntry;
  bool _isColumnsDropdownOpen = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _closeColumnsDropdown();
    super.dispose();
  }

  void _closeColumnsDropdown() {
    if (_columnsOverlayEntry != null) {
      _columnsOverlayEntry!.remove();
      _columnsOverlayEntry = null;
    }
    if (_isColumnsDropdownOpen && mounted) {
      setState(() => _isColumnsDropdownOpen = false);
    }
  }

  void _toggleColumnsDropdown() {
    if (_isColumnsDropdownOpen) {
      _closeColumnsDropdown();
    } else {
      _showColumnsDropdown();
    }
  }

  void _showColumnsDropdown() {
    final renderBox = _columnsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _columnsOverlayEntry = OverlayEntry(
      builder: (ctx) {
        final pref = ref.watch(columnPreferenceProvider(_tableId)).valueOrNull;
        final currentVisibleSet = _getEffectiveVisibleColumns(pref);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeColumnsDropdown,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              width: 250,
              child: CompositedTransformFollower(
                link: _columnsLayerLink,
                showWhenUnlinked: false,
                offset: Offset(size.width - 250, size.height + 6),
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 460),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEAECF0), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Toggle Columns',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _toggleAllColumns(true),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                      child: Text(
                                        'All',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _resetColumnsToDefault,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                      child: Text(
                                        'Reset',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF667085),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEAECF0)),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _defaultAllColumns.length,
                            itemBuilder: (context, index) {
                              final col = _defaultAllColumns[index];
                              final isChecked = currentVisibleSet.contains(col);
                              return InkWell(
                                onTap: () => _toggleColumn(col, !isChecked),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  child: Row(
                                    children: [
                                      IgnorePointer(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Checkbox(
                                            value: isChecked,
                                            activeColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            onChanged: (_) {},
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          col,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                            color: isChecked ? const Color(0xFF101828) : const Color(0xFF667085),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEAECF0)),
                        InkWell(
                          onTap: () {
                            _closeColumnsDropdown();
                            _openColumnSelection(context, pref);
                          },
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: const [
                                Icon(Icons.tune, size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Reorder & Settings...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_columnsOverlayEntry!);
    setState(() => _isColumnsDropdownOpen = true);
  }

  Widget _buildColumnsDropdownButton(
    BuildContext context,
    List<String> visibleCols,
    dynamic pref,
  ) {
    return CompositedTransformTarget(
      link: _columnsLayerLink,
      child: InkWell(
        key: _columnsButtonKey,
        onTap: _toggleColumnsDropdown,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _isColumnsDropdownOpen ? const Color(0xFFF9FAFB) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isColumnsDropdownOpen ? AppColors.primary : const Color(0xFFD0D5DD),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.view_column_outlined, size: 18, color: Color(0xFF344054)),
              SizedBox(width: 6),
              Text(
                'Columns',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF667085)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleColumn(String col, bool enable) {
    final current = Set<String>.from(
      _getEffectiveVisibleColumns(ref.read(columnPreferenceProvider(_tableId)).valueOrNull),
    );

    if (enable) {
      current.add(col);
    } else {
      if (current.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('At least one column must remain visible.')),
        );
        return;
      }
      current.remove(col);
    }

    setState(() {
      _activeVisibleColumns = current;
    });

    _columnsOverlayEntry?.markNeedsBuild();

    final ordered = _defaultAllColumns.where((c) => current.contains(c)).toList();
    final pref = ColumnPreference(
      tableId: _tableId,
      visibleColumns: ordered,
      columnOrder: _defaultAllColumns,
    );

    ref.read(organizationRepositoryProvider).saveColumnPreference(pref);
  }

  void _toggleAllColumns(bool selectAll) {
    final updated = selectAll ? _defaultAllColumns.toSet() : {_defaultAllColumns.first};
    setState(() {
      _activeVisibleColumns = updated;
    });

    _columnsOverlayEntry?.markNeedsBuild();

    final ordered = _defaultAllColumns.where((c) => updated.contains(c)).toList();
    final pref = ColumnPreference(
      tableId: _tableId,
      visibleColumns: ordered,
      columnOrder: _defaultAllColumns,
    );

    ref.read(organizationRepositoryProvider).saveColumnPreference(pref);
  }

  void _resetColumnsToDefault() {
    setState(() {
      _activeVisibleColumns = _defaultAllColumns.toSet();
    });

    _columnsOverlayEntry?.markNeedsBuild();

    final pref = ColumnPreference(
      tableId: _tableId,
      visibleColumns: List<String>.from(_defaultAllColumns),
      columnOrder: _defaultAllColumns,
    );

    ref.read(organizationRepositoryProvider).saveColumnPreference(pref);
  }

  Widget _buildActiveFilterChips() {
    if (_activeFiltersCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Filters:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          if (_selectedBusinessTypeFilter != 'All')
            _buildFilterChip('Business: $_selectedBusinessTypeFilter', () {
              setState(() {
                _selectedBusinessTypeFilter = 'All';
                _currentPage = 0;
              });
            }),
          if (_selectedIndustryTypeFilter != 'All')
            _buildFilterChip('Industry: $_selectedIndustryTypeFilter', () {
              setState(() {
                _selectedIndustryTypeFilter = 'All';
                _currentPage = 0;
              });
            }),
          InkWell(
            onTap: () {
              setState(() {
                _selectedBusinessTypeFilter = 'All';
                _selectedIndustryTypeFilter = 'All';
                _currentPage = 0;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('Reset All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _openFilterModal(BuildContext context, List<Organization> allOrgs) {
    final businessOptions = <String>{'All', ...allOrgs.map((o) => o.businessType).where((s) => s.isNotEmpty)}.toList();
    final industryOptions = <String>{'All', ...allOrgs.map((o) => o.industryType).where((s) => s.isNotEmpty)}.toList();

    String tempBusiness = _selectedBusinessTypeFilter;
    String tempIndustry = _selectedIndustryTypeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Organizations',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempBusiness = 'All';
                            tempIndustry = 'All';
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  AppSearchableDropdown<String>(
                    label: 'Business Type',
                    value: tempBusiness,
                    items: businessOptions,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tempBusiness = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  AppSearchableDropdown<String>(
                    label: 'Industry Type',
                    value: tempIndustry,
                    items: industryOptions,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tempIndustry = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedBusinessTypeFilter = tempBusiness;
                          _selectedIndustryTypeFilter = tempIndustry;
                          _currentPage = 0;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openColumnSelection(BuildContext context, dynamic currentPref) {
    ColumnSelectionDialog.show(
      context,
      tableId: _tableId,
      allColumns: _defaultAllColumns,
      currentPreferences: currentPref is ColumnPreference ? currentPref : null,
    );
  }

  void _openAddDialog(BuildContext context) {
    OrganizationFormDialog.show(context);
  }

  void _openEditDialog(BuildContext context, Organization org) {
    OrganizationFormDialog.show(context, organization: org);
  }

  void _openViewDialog(BuildContext context, Organization org) {
    showDialog<void>(
      context: context,
      builder: (context) => OrganizationDetailsDialog(organization: org),
    );
  }

  void _openShareDialog(BuildContext context, Organization org) {
    OrganizationShareDialog.show(context, org);
  }

  Future<void> _toggleStatus(BuildContext context, Organization org) async {
    final newStatus = org.isActive ? 'inactive' : 'active';
    final actionName = org.isActive ? 'Deactivate' : 'Reactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionName "${org.name}"?'),
        content: Text(
          org.isActive
              ? 'Deactivating will hide this organization from normal selection while preserving all historical employee, department, attendance, and payroll records intact.'
              : 'Reactivating will restore this organization to active selection and operational modules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: org.isActive ? const Color(0xFFD97706) : AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (org.isActive) {
        await ref.read(organizationRepositoryProvider).deactivateOrganization(org.id, org.docId);
      } else {
        await ref.read(organizationRepositoryProvider).reactivateOrganization(org.id, org.docId);
      }
      ref.invalidate(organizationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Organization is now $newStatus.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Organization org) async {
    // Audit dependencies first
    final deps = await ref.read(organizationRepositoryProvider).checkOrganizationDependencies(org.canonicalId, org.name);
    final totalDeps = deps.values.fold<int>(0, (sum, val) => sum + val);

    if (totalDeps > 0) {
      if (!mounted) return;
      final shouldDeactivate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Deletion Blocked'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cannot permanently delete "${org.name}" because it has $totalDeps associated records:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...deps.entries.where((e) => e.value > 0).map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.value} ${e.key.replaceAll('_', ' ')}'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To protect employee attendance, leave, and payroll history, please deactivate this organization instead.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              label: const Text('Deactivate Organization'),
            ),
          ],
        ),
      );

      if (shouldDeactivate == true) {
        await ref.read(organizationRepositoryProvider).deactivateOrganization(org.id, org.docId);
        ref.invalidate(organizationsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Deactivated "${org.name}"')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${org.name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(organizationRepositoryProvider).deleteOrganization(org.id, org.docId);
      ref.invalidate(organizationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Deleted "${org.name}"')),
      );
    }
  }

  void _openMigrationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _MigrationManagementDialog(),
    );
  }

  Widget _buildDesktopTable(
    List<Organization> orgs,
    List<String> visibleColumns,
    double screenWidth,
  ) {
    // Dynamic width calculation based on visible columns
    double totalColWidth = 60.0; // checkbox column
    for (final col in visibleColumns) {
      totalColWidth += _getColumnWidth(col) + 24.0;
    }
    totalColWidth += 90.0; // Actions column

    final minTableWidth = totalColWidth.clamp(900.0, 3200.0);

    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return Colors.transparent;
          }),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: const BorderSide(color: Color(0xFFD0D5DD), width: 1.5),
        ),
      ),
      child: Scrollbar(
        controller: _horizontalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 8.0,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: screenWidth < minTableWidth ? minTableWidth : screenWidth,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 70,
                horizontalMargin: 16,
                columnSpacing: 20,
                showCheckboxColumn: true,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF9CC70A).withValues(alpha: 0.08);
                  }
                  return Colors.white;
                }),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                onSelectAll: (selected) {
                  setState(() {
                    if (selected == true) {
                      for (final org in orgs) {
                        _selectedIds.add(org.id);
                      }
                    } else {
                      for (final org in orgs) {
                        _selectedIds.remove(org.id);
                      }
                    }
                  });
                },
                columns: [
                  for (final colName in visibleColumns)
                    DataColumn(
                      label: SizedBox(
                        width: _getColumnWidth(colName),
                        child: Text(
                          colName.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  const DataColumn(
                    label: SizedBox(
                      width: 70,
                      child: Text(
                        'ACTIONS',
                        style: TextStyle(
                          color: Color(0xFF475467),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: orgs.map((org) {
                  final isSelected = _selectedIds.contains(org.id);
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(org.id);
                        } else {
                          _selectedIds.remove(org.id);
                        }
                      });
                    },
                    cells: [
                      for (final colName in visibleColumns)
                        DataCell(
                          SizedBox(
                            width: _getColumnWidth(colName),
                            child: _buildCellContent(colName, org),
                          ),
                        ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: _buildRowActionsMenu(context, org),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getColumnWidth(String columnName) {
    switch (columnName) {
      case 'Organization Name':
        return 180;
      case 'Business Type':
        return 150;
      case 'Industry Type':
        return 130;
      case 'Business Unit(s)':
        return 140;
      case 'Location(s)':
        return 130;
      case 'Address':
        return 200;
      case 'Phone Number':
        return 150;
      case 'Email Address':
        return 180;
      case 'Website':
        return 180;
      case 'GST / VAT Number':
      case 'Tax Identification Number (GST/VAT/TIN)':
        return 150;
      case 'CIN Number':
        return 130;
      case 'PAN Number':
        return 130;
      case 'TAN Number':
        return 130;
      case 'Directors / DIN':
        return 150;
      case 'Documents':
        return 120;
      default:
        return 140;
    }
  }

  Widget _buildRowActionsMenu(BuildContext context, Organization org) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF2F4F7)),
          ),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.12),
        ),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert,
          size: 20,
          color: Color(0xFF98A2B3),
        ),
        tooltip: 'Row Actions',
        offset: const Offset(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFF2F4F7)),
        ),
        elevation: 6,
        color: Colors.white,
        itemBuilder: (ctx) => [
          PopupMenuItem<String>(
            value: 'view',
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                SizedBox(width: 12),
                Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'edit',
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                SizedBox(width: 12),
                Text(
                  'Edit Organization',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'share',
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                SizedBox(width: 12),
                Text(
                  'Share Organization',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'status_toggle',
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  org.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 20,
                  color: org.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 12),
                Text(
                  org.isActive ? 'Deactivate' : 'Reactivate',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: org.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFFF4D4F),
                ),
                SizedBox(width: 12),
                Text(
                  'Delete Organization',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF4D4F),
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (val) {
          if (val == 'view') {
            _openViewDialog(context, org);
          } else if (val == 'edit') {
            _openEditDialog(context, org);
          } else if (val == 'share') {
            _openShareDialog(context, org);
          } else if (val == 'status_toggle') {
            _toggleStatus(context, org);
          } else if (val == 'delete') {
            _confirmDelete(context, org);
          }
        },
      ),
    );
  }

  Widget _buildCellContent(String columnName, Organization org) {
    String value = '';
    TextStyle? style;

    switch (columnName) {
      case 'Status':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: org.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: org.isActive ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: org.isActive ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                org.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: org.isActive ? const Color(0xFF166534) : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        );
      case 'Organization Name':
        value = org.name.toUpperCase();
        style = const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF101828),
          fontSize: 13,
          letterSpacing: 0.2,
        );
        break;
      case 'Business Type':
        value = org.businessType;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Industry Type':
        value = org.industryType;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Business Unit(s)':
        value = org.businessUnits;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Location(s)':
        value = org.locations;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Address':
        value = org.address;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Phone Number':
        if (org.contactNumbers.isNotEmpty) {
          value = org.contactNumbers.map((c) => '${c.label}:\n${c.number}').join('\n');
        } else {
          value = org.phoneNumber;
        }
        style = const TextStyle(fontSize: 12, color: Color(0xFF344054));
        break;
      case 'Email Address':
        value = org.emailAddress;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Website':
        value = org.website;
        style = const TextStyle(
          fontSize: 12.5,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        );
        break;
      case 'GST / VAT Number':
      case 'Tax Identification Number (GST/VAT/TIN)':
        value = org.gstNumber.isNotEmpty ? org.gstNumber : org.taxId;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'CIN Number':
        value = org.cinNumber;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'PAN Number':
        value = org.panNumber;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'TAN Number':
        value = org.tanNumber;
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Directors / DIN':
        value = org.directors.isNotEmpty
            ? org.directors.map((d) => d.din.isNotEmpty ? '${d.name} (${d.din})' : d.name).join(', ')
            : '';
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      case 'Documents':
        value = org.documents.isNotEmpty ? '${org.documents.length} document(s)' : '';
        style = const TextStyle(fontSize: 12.5, color: Color(0xFF344054));
        break;
      default:
        value = '';
    }

    final displayText = value.trim().isEmpty ? '-' : value;

    return Tooltip(
      message: displayText,
      waitDuration: const Duration(milliseconds: 600),
      child: Text(
        displayText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style ?? const TextStyle(fontSize: 12.5, color: Color(0xFF344054)),
      ),
    );
  }

  Widget _buildMobileList(List<Organization> orgs) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: orgs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final org = orgs[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Neutral light gray icon box (#F3F4F6)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Color(0xFF475467),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            org.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (org.businessType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFDBEAFE)),
                                  ),
                                  child: Text(
                                    org.businessType,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                ),
                              if (org.industryType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Text(
                                    org.industryType,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B21A8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action Menu with 44x44 pt minimum touch target
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF667085)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('View Details', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit Organization', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Share Organization', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'status_toggle',
                            child: Row(
                              children: [
                                Icon(
                                  org.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                  size: 18,
                                  color: org.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  org.isActive ? 'Deactivate' : 'Reactivate',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: org.isActive ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Delete Organization', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'view') _openViewDialog(context, org);
                          if (val == 'edit') _openEditDialog(context, org);
                          if (val == 'share') _openShareDialog(context, org);
                          if (val == 'status_toggle') _toggleStatus(context, org);
                          if (val == 'delete') _confirmDelete(context, org);
                        },
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFEAECF0)),
                ),
                if (org.locations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            org.locations,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF344054)),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (org.businessUnits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF9333EA)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            org.businessUnits,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF344054)),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    if (org.phoneNumber.isNotEmpty) ...[
                      const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF667085)),
                      const SizedBox(width: 6),
                      Text(
                        org.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF344054)),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (org.taxId.isNotEmpty) ...[
                      const Icon(Icons.receipt_long_outlined, size: 15, color: Color(0xFF667085)),
                      const SizedBox(width: 6),
                      Text(
                        'GST: ${org.taxId}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF344054), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
    required bool isMobile,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalItems == 0 ? 'Showing 0 of 0' : 'Showing ${startIndex + 1} - $endIndex of $totalItems',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085), fontWeight: FontWeight.w500),
          ),
          if (!isMobile)
            Row(
              children: [
                const Text('Rows per page ', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _rowsPerPage,
                    isDense: true,
                    items: [5, 10, 20, 50].map((val) => DropdownMenuItem(value: val, child: Text('$val', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _rowsPerPage = val;
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: currentPage > 0 ? () => setState(() => _currentPage -= 1) : null,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${currentPage + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage += 1) : null,
                ),
              ],
            )
          else
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: currentPage > 0 ? () => setState(() => _currentPage -= 1) : null,
                ),
                Text(
                  '${currentPage + 1} / ${totalPages == 0 ? 1 : totalPages}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF344054)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: currentPage < totalPages - 1 ? () => setState(() => _currentPage += 1) : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MigrationManagementDialog extends StatefulWidget {
  const _MigrationManagementDialog();

  @override
  State<_MigrationManagementDialog> createState() => _MigrationManagementDialogState();
}

class _MigrationManagementDialogState extends State<_MigrationManagementDialog> {
  bool _isLoading = false;
  MigrationReport? _report;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runMigration(dryRun: true);
  }

  Future<void> _runMigration({required bool dryRun}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = OrganizationMigrationService();
      final res = await service.runMigration(dryRun: dryRun);
      setState(() {
        _report = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.published_with_changes_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Organization ID Migration & Health Audit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                      ),
                      Text(
                        'Audit records across Firestore collections and securely link them to canonical organization IDs.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF667085)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEAECF0)),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing Firestore collections...'),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                ),
              )
            else if (_report != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _report!.isDryRun ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _report!.isDryRun ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _report!.isDryRun ? Icons.info_outline : Icons.check_circle_outline,
                            color: _report!.isDryRun ? const Color(0xFF2563EB) : const Color(0xFF059669),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _report!.isDryRun
                                  ? 'DRY-RUN ANALYSIS COMPLETED: No data has been modified. Review the summary below before applying.'
                                  : 'MIGRATION APPLIED SUCCESSFULLY: Matched records have been updated with canonical organization IDs.',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _report!.isDryRun ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Summary Cards Row
                    Row(
                      children: [
                        _buildStatBox('Organizations', '${_report!.totalOrganizationsFound}', Colors.blueGrey),
                        const SizedBox(width: 8),
                        _buildStatBox('Already Linked', '${_report!.totalAlreadyMigrated}', const Color(0xFF059669)),
                        const SizedBox(width: 8),
                        _buildStatBox('Ready to Link', '${_report!.totalMatched}', const Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        _buildStatBox('Unmatched', '${_report!.totalUnmatched}', const Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        _buildStatBox('Ambiguous', '${_report!.totalAmbiguous}', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Detailed Log:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _report!.toFormattedString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _runMigration(dryRun: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-run Dry-Run'),
                ),
                if (_report != null && _report!.isDryRun && _report!.totalMatched > 0) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _isLoading ? null : () => _runMigration(dryRun: false),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: Text('Apply Migration (${_report!.totalMatched} records)'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
