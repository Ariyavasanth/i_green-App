import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/department.dart';
import '../domain/designation.dart';
import '../domain/column_preference.dart';
import '../providers/organization_providers.dart';
import 'widgets/column_selection_dialog.dart';
import 'widgets/department_details_dialog.dart';
import 'widgets/department_form_dialog.dart';
import 'widgets/designation_form_dialog.dart';
import '../../../../core/widgets/app_searchable_dropdown.dart';

class OrganizationStructurePage extends ConsumerStatefulWidget {
  const OrganizationStructurePage({super.key});

  @override
  ConsumerState<OrganizationStructurePage> createState() =>
      _OrganizationStructurePageState();
}

class _OrganizationStructurePageState
    extends ConsumerState<OrganizationStructurePage> {
  static const String _deptTableId = 'organization_structure_table';

  static const List<String> _defaultAllColumns = [
    'Organization Name',
    'Department Name',
    'Department Head',
    'Work Location',
  ];

  int _selectedTab = 0; // 0 = Departments, 1 = Designations

  // Departments tab state
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<int> _selectedIds = {};
  String _selectedOrgFilter = 'All';
  String _selectedDeptFilter = 'All';
  String _selectedLocationFilter = 'All';

  // Designations tab state
  String _selectedDesigOrg = 'All';
  String _selectedDesigDept = 'All';

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedOrgFilter != 'All') count++;
    if (_selectedDeptFilter != 'All') count++;
    if (_selectedLocationFilter != 'All') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final deptsAsync = ref.watch(departmentsProvider);
    final desigsAsync = ref.watch(allDesignationsProvider);

    final totalDepts = deptsAsync.valueOrNull?.length;
    final deptTabTitle = totalDepts != null ? 'Departments ($totalDepts)' : 'Departments';

    final totalDesigs = desigsAsync.valueOrNull?.length;
    final desigTabTitle = totalDesigs != null ? 'Designations ($totalDesigs)' : 'Designations';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Tab Bar [ Departments (n) ] [ Designations (n) ]
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEAECF0))),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  title: deptTabTitle,
                  icon: Icons.apartment_rounded,
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  title: desigTabTitle,
                  icon: Icons.badge_outlined,
                  isSelected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF9CC70A),
              onRefresh: () async {
                ref.invalidate(departmentsProvider);
                ref.invalidate(allDesignationsProvider);
                ref.invalidate(organizationsProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: _selectedTab == 0
                  ? _buildDepartmentsView(context, isMobile)
                  : _buildDesignationsView(context, isMobile),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFD0D5DD),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : const Color(0xFF667085),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF344054),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DEPARTMENTS TAB VIEW
  // ==========================================
  Widget _buildDepartmentsView(BuildContext context, bool isMobile) {
    final deptsAsync = ref.watch(departmentsProvider);
    final prefAsync = ref.watch(columnPreferenceProvider(_deptTableId));
    final searchQuery = ref.watch(deptSearchQueryProvider);

    return Column(
      children: [
        _buildDeptToolbar(context, prefAsync, deptsAsync.valueOrNull ?? [], isMobile),
        _buildActiveDeptFilterChips(),
        const Divider(height: 1, color: Color(0xFFEAECF0)),
        Expanded(
          child: deptsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Unable to load departments: $err'),
            ),
            data: (depts) {
              final filtered = depts.where((dept) {
                if (_selectedOrgFilter != 'All' && dept.organizationName != _selectedOrgFilter) {
                  return false;
                }
                if (_selectedDeptFilter != 'All' && dept.departmentName != _selectedDeptFilter) {
                  return false;
                }
                if (_selectedLocationFilter != 'All' && dept.workLocation != _selectedLocationFilter) {
                  return false;
                }
                if (searchQuery.trim().isEmpty) return true;
                final q = searchQuery.toLowerCase();
                return dept.organizationName.toLowerCase().contains(q) ||
                    dept.departmentName.toLowerCase().contains(q) ||
                    dept.departmentHead.toLowerCase().contains(q) ||
                    dept.workLocation.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No departments found.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              final pref = prefAsync.valueOrNull;
              List<String> visibleCols;
              if (pref != null && pref.visibleColumns.isNotEmpty) {
                visibleCols = pref.visibleColumns;
              } else {
                visibleCols = List.from(_defaultAllColumns);
              }

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
                        ? _buildDeptMobileList(pageItems)
                        : _buildDeptDesktopTable(
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
      ],
    );
  }

  Widget _buildDeptToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
    List<Department> allDepts,
    bool isMobile,
  ) {
    final searchController = TextEditingController(
      text: ref.read(deptSearchQueryProvider),
    );
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

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
                  hintText: 'Search departments...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF667085)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF667085)),
                          onPressed: () {
                            ref.read(deptSearchQueryProvider.notifier).state = '';
                            setState(() => _currentPage = 0);
                          },
                        ),
                      InkWell(
                        onTap: () => _openDeptFilterModal(context, allDepts),
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
                  ref.read(deptSearchQueryProvider.notifier).state = val;
                  setState(() => _currentPage = 0);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMobile)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(42, 42),
              ),
              tooltip: 'Add Department',
              onPressed: () => _openAddDeptDialog(context),
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
              onPressed: () => _openAddDeptDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Department',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveDeptFilterChips() {
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
          if (_selectedOrgFilter != 'All')
            _buildFilterChip('Org: $_selectedOrgFilter', () {
              setState(() {
                _selectedOrgFilter = 'All';
                _currentPage = 0;
              });
            }),
          if (_selectedDeptFilter != 'All')
            _buildFilterChip('Dept: $_selectedDeptFilter', () {
              setState(() {
                _selectedDeptFilter = 'All';
                _currentPage = 0;
              });
            }),
          if (_selectedLocationFilter != 'All')
            _buildFilterChip('Location: $_selectedLocationFilter', () {
              setState(() {
                _selectedLocationFilter = 'All';
                _currentPage = 0;
              });
            }),
          InkWell(
            onTap: () {
              setState(() {
                _selectedOrgFilter = 'All';
                _selectedDeptFilter = 'All';
                _selectedLocationFilter = 'All';
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
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
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

  void _openDeptFilterModal(BuildContext context, List<Department> allDepts) {
    final orgOptions = <String>{'All', ...allDepts.map((d) => d.organizationName).where((s) => s.isNotEmpty)}.toList();
    final deptOptions = <String>{'All', ...allDepts.map((d) => d.departmentName).where((s) => s.isNotEmpty)}.toList();
    final locOptions = <String>{'All', ...allDepts.map((d) => d.workLocation).where((s) => s.isNotEmpty)}.toList();

    String tempOrg = _selectedOrgFilter;
    String tempDept = _selectedDeptFilter;
    String tempLoc = _selectedLocationFilter;

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
                        'Filter Departments',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempOrg = 'All';
                            tempDept = 'All';
                            tempLoc = 'All';
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  AppSearchableDropdown<String>(
                    label: 'Organization',
                    value: tempOrg,
                    items: orgOptions,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tempOrg = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  AppSearchableDropdown<String>(
                    label: 'Department',
                    value: tempDept,
                    items: deptOptions,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tempDept = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  AppSearchableDropdown<String>(
                    label: 'Work Location',
                    value: tempLoc,
                    items: locOptions,
                    onChanged: (val) {
                      if (val != null) setModalState(() => tempLoc = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openColumnSelection(context, ref.read(columnPreferenceProvider(_deptTableId)).valueOrNull);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFD0D5DD)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF344054)),
                          label: const Text('Columns', style: TextStyle(color: Color(0xFF344054), fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedOrgFilter = tempOrg;
                              _selectedDeptFilter = tempDept;
                              _selectedLocationFilter = tempLoc;
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
      tableId: _deptTableId,
      allColumns: _defaultAllColumns,
      currentPreferences: currentPref is ColumnPreference ? currentPref : null,
    );
  }

  void _openAddDeptDialog(BuildContext context) {
    DepartmentFormDialog.show(context);
  }

  void _openEditDeptDialog(BuildContext context, Department dept) {
    DepartmentFormDialog.show(context, department: dept);
  }

  void _openViewDeptDialog(BuildContext context, Department dept) {
    showDialog<void>(
      context: context,
      builder: (context) => DepartmentDetailsDialog(department: dept),
    );
  }

  Future<void> _confirmDeleteDept(BuildContext context, Department dept) async {
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
          'Are you sure you want to delete department "${dept.departmentName}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(organizationRepositoryProvider).deleteDepartment(dept.id);
      ref.invalidate(departmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${dept.departmentName}"')),
      );
    }
  }

  Widget _buildDeptDesktopTable(
    List<Department> depts,
    List<String> visibleColumns,
    double screenWidth,
  ) {
    final minTableWidth = (visibleColumns.length * 180.0 + 120.0).clamp(600.0, 1600.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: screenWidth < minTableWidth ? minTableWidth : screenWidth,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            horizontalMargin: 16,
            columnSpacing: 24,
            showCheckboxColumn: true,
            headingTextStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
            columns: [
              for (final colName in visibleColumns)
                DataColumn(label: Text(colName.toUpperCase())),
              const DataColumn(label: Text('ACTIONS')),
            ],
            rows: depts.map((dept) {
              final isSelected = _selectedIds.contains(dept.id);
              return DataRow(
                selected: isSelected,
                onSelectChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(dept.id);
                    } else {
                      _selectedIds.remove(dept.id);
                    }
                  });
                },
                cells: [
                  for (final colName in visibleColumns)
                    DataCell(_buildDeptCellContent(colName, dept)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'View Details',
                          onPressed: () => _openViewDeptDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'Edit Department',
                          onPressed: () => _openEditDeptDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Department',
                          onPressed: () => _confirmDeleteDept(context, dept),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDeptCellContent(String columnName, Department dept) {
    String value = '';
    TextStyle? style;

    switch (columnName) {
      case 'Organization Name':
        value = dept.organizationName;
        style = const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF667085));
        break;
      case 'Department Name':
        value = dept.departmentName;
        style = const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF101828), fontSize: 14);
        break;
      case 'Department Head':
        value = dept.departmentHead;
        break;
      case 'Work Location':
        value = dept.workLocation;
        break;
      default:
        value = '';
    }

    return SizedBox(
      width: 160,
      child: Text(
        value.isEmpty ? '-' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style ?? const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildDeptMobileList(List<Department> depts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: depts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dept = depts[index];
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
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
                            dept.departmentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (dept.organizationName.isNotEmpty)
                            Text(
                              dept.organizationName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                                Text('Edit Department', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Delete Department', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'view') _openViewDeptDialog(context, dept);
                          if (val == 'edit') _openEditDeptDialog(context, dept);
                          if (val == 'delete') _confirmDeleteDept(context, dept);
                        },
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFEAECF0)),
                ),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF667085)),
                    const SizedBox(width: 6),
                    const Text('Head: ', style: TextStyle(fontSize: 13, color: Color(0xFF667085))),
                    Text(
                      dept.departmentHead.isEmpty ? '-' : dept.departmentHead,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (dept.workLocation.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          dept.workLocation,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // DESIGNATIONS TAB VIEW
  // ==========================================
  Widget _buildDesignationsView(BuildContext context, bool isMobile) {
    final orgsAsync = ref.watch(organizationsProvider);
    final deptsAsync = ref.watch(departmentsProvider);
    final desigsAsync = ref.watch(allDesignationsProvider);
    final searchQuery = ref.watch(desigSearchQueryProvider);

    return Column(
      children: [
        // Filter Bar (Organization & Department Selectors)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            border: Border(bottom: BorderSide(color: Color(0xFFEAECF0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                Row(
                  children: [
                    // Organization Selector
                    Expanded(
                      child: orgsAsync.when(
                        loading: () => const SizedBox(height: 42, child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (orgs) {
                          final orgNames = ['All', ...orgs.map((o) => o.name).where((s) => s.isNotEmpty).toSet()];
                          return AppSearchableDropdown<String>(
                            label: 'Organization',
                            value: _selectedDesigOrg,
                            items: orgNames,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedDesigOrg = val;
                                  _selectedDesigDept = 'All';
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Department Selector
                    Expanded(
                      child: deptsAsync.when(
                        loading: () => const SizedBox(height: 42, child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (depts) {
                          var filteredDepts = depts;
                          if (_selectedDesigOrg != 'All') {
                            filteredDepts = depts.where((d) => d.organizationName == _selectedDesigOrg).toList();
                          }
                          final deptNames = ['All', ...filteredDepts.map((d) => d.departmentName).where((s) => s.isNotEmpty).toSet()];
                          return AppSearchableDropdown<String>(
                            label: 'Department',
                            value: _selectedDesigDept,
                            items: deptNames,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDesigDept = val);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    orgsAsync.when(
                      loading: () => const SizedBox(height: 42),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (orgs) {
                        final orgNames = ['All', ...orgs.map((o) => o.name).where((s) => s.isNotEmpty).toSet()];
                        return AppSearchableDropdown<String>(
                          label: 'Organization',
                          value: _selectedDesigOrg,
                          items: orgNames,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDesigOrg = val;
                                _selectedDesigDept = 'All';
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    deptsAsync.when(
                      loading: () => const SizedBox(height: 42),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (depts) {
                        var filteredDepts = depts;
                        if (_selectedDesigOrg != 'All') {
                          filteredDepts = depts.where((d) => d.organizationName == _selectedDesigOrg).toList();
                        }
                        final deptNames = ['All', ...filteredDepts.map((d) => d.departmentName).where((s) => s.isNotEmpty).toSet()];
                        return AppSearchableDropdown<String>(
                          label: 'Department',
                          value: _selectedDesigDept,
                          items: deptNames,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDesigDept = val);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Designations Search & Add Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search designations...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF667085)),
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
                      ref.read(desigSearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isMobile)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(42, 42),
                  ),
                  tooltip: 'Add Designation',
                  onPressed: () => _openAddDesigDialog(context),
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
                  onPressed: () => _openAddDesigDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add Designation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFEAECF0)),

        // Designations List / Grid
        Expanded(
          child: desigsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Unable to load designations: $err')),
            data: (desigs) {
              final filtered = desigs.where((d) {
                if (_selectedDesigOrg != 'All' &&
                    d.organizationName.isNotEmpty &&
                    d.organizationName != _selectedDesigOrg) {
                  return false;
                }
                if (_selectedDesigDept != 'All' &&
                    d.departmentName != _selectedDesigDept) {
                  return false;
                }
                if (searchQuery.trim().isEmpty) return true;
                final q = searchQuery.toLowerCase();
                return d.designationName.toLowerCase().contains(q) ||
                    d.departmentName.toLowerCase().contains(q) ||
                    d.organizationName.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text(
                          'No designations found for selected criteria.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: () => _openAddDesigDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Designation'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final d = filtered[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.designationName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      d.departmentName,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475467)),
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final orgName = d.organizationName.isNotEmpty
                                          ? d.organizationName
                                          : (deptsAsync.valueOrNull
                                                  ?.where((dept) => dept.departmentName == d.departmentName)
                                                  .firstOrNull
                                                  ?.organizationName ??
                                              '');
                                      if (orgName.isEmpty) return const SizedBox.shrink();
                                      return Text(
                                        '•  $orgName',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                              tooltip: 'Edit Designation',
                              onPressed: () => _openEditDesigDialog(context, d),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Delete Designation',
                              onPressed: () => _confirmDeleteDesig(context, d),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddDesigDialog(BuildContext context) {
    DesignationFormDialog.show(
      context,
      initialOrganization: _selectedDesigOrg,
      initialDepartment: _selectedDesigDept,
    );
  }

  void _openEditDesigDialog(BuildContext context, Designation designation) {
    DesignationFormDialog.show(context, designation: designation);
  }

  Future<void> _confirmDeleteDesig(BuildContext context, Designation designation) async {
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
          'Are you sure you want to delete designation "${designation.designationName}" in ${designation.departmentName}?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(organizationRepositoryProvider).deleteDesignation(designation.id);
      ref.invalidate(allDesignationsProvider);
      ref.invalidate(designationsProvider(designation.departmentName));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${designation.designationName}"')),
      );
    }
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
