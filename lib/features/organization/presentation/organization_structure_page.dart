import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/department.dart';
import '../providers/organization_providers.dart';
import 'widgets/column_selection_dialog.dart';
import 'widgets/department_details_dialog.dart';
import 'widgets/department_form_dialog.dart';

class OrganizationStructurePage extends ConsumerStatefulWidget {
  const OrganizationStructurePage({super.key});

  @override
  ConsumerState<OrganizationStructurePage> createState() =>
      _OrganizationStructurePageState();
}

class _OrganizationStructurePageState
    extends ConsumerState<OrganizationStructurePage> {
  static const String _tableId = 'organization_structure_table';

  static const List<String> _defaultAllColumns = [
    'Organization Name',
    'Department Name',
    'Department Head',
    'Reporting Hierarchy',
    'Work Location',
  ];

  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(departmentsProvider);
    final prefAsync = ref.watch(columnPreferenceProvider(_tableId));
    final searchQuery = ref.watch(deptSearchQueryProvider);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _buildToolbar(context, prefAsync),
          const Divider(height: 1),
          Expanded(
            child: deptsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Unable to load departments: $err'),
              ),
              data: (depts) {
                final filtered = depts.where((dept) {
                  if (searchQuery.trim().isEmpty) return true;
                  final q = searchQuery.toLowerCase();
                  return dept.organizationName.toLowerCase().contains(q) ||
                      dept.departmentName.toLowerCase().contains(q) ||
                      dept.departmentHead.toLowerCase().contains(q) ||
                      dept.reportingHierarchy.toLowerCase().contains(q) ||
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

                // Determine active visible columns and ordering from user preferences
                final pref = prefAsync.valueOrNull;
                List<String> visibleCols;
                if (pref != null && pref.visibleColumns.isNotEmpty) {
                  visibleCols = pref.visibleColumns;
                } else {
                  visibleCols = List.from(_defaultAllColumns);
                }

                // Calculate pagination
                final totalItems = filtered.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();
                final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
                final startIndex = pageIndex * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 650
                                ? _buildMobileList(pageItems)
                                : _buildDesktopTable(
                                    pageItems,
                                    visibleCols,
                                    constraints.maxWidth,
                                  ),
                      ),
                    ),
                    _buildPaginationBar(
                      totalItems: totalItems,
                      startIndex: startIndex,
                      endIndex: endIndex,
                      currentPage: pageIndex,
                      totalPages: totalPages,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
  ) {
    final searchController = TextEditingController(
      text: ref.read(deptSearchQueryProvider),
    );
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Organization Structure',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: isCompact ? 150 : 200,
                    height: 36,
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search departments...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  ref
                                      .read(deptSearchQueryProvider.notifier)
                                      .state = '';
                                  setState(() => _currentPage = 0);
                                },
                              )
                            : null,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: AppColors.active),
                        ),
                      ),
                      onChanged: (val) {
                        ref.read(deptSearchQueryProvider.notifier).state = val;
                        setState(() => _currentPage = 0);
                      },
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      onPressed: () => _openColumnSelectionDialog(context),
                      icon: const Icon(Icons.view_column_outlined, size: 18),
                      label: const Text('Columns', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.active,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _openAddDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      isCompact ? 'Add' : 'Add Department',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openColumnSelectionDialog(BuildContext context) async {
    final pref = ref.read(columnPreferenceProvider(_tableId)).valueOrNull;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: _tableId,
        allColumns: _defaultAllColumns,
        currentVisibleColumns:
            pref?.visibleColumns ?? List.from(_defaultAllColumns),
        currentColumnOrder: pref?.columnOrder ?? List.from(_defaultAllColumns),
      ),
    );

    if (updated == true) {
      ref.invalidate(columnPreferenceProvider(_tableId));
    }
  }

  void _openViewDialog(BuildContext context, Department dept) {
    showDialog<void>(
      context: context,
      builder: (context) => DepartmentDetailsDialog(department: dept),
    );
  }

  void _openAddDialog(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => const DepartmentFormDialog(),
    );
  }

  void _openEditDialog(BuildContext context, Department dept) {
    showDialog<bool>(
      context: context,
      builder: (context) => DepartmentFormDialog(department: dept),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Department dept) async {
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
      await ref
          .read(organizationRepositoryProvider)
          .deleteDepartment(dept.id);
      ref.invalidate(departmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${dept.departmentName}"')),
      );
    }
  }

  Widget _buildDesktopTable(
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
                    DataCell(_buildCellContent(colName, dept)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined,
                              size: 18, color: AppColors.active),
                          tooltip: 'View Details',
                          onPressed: () => _openViewDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.active),
                          tooltip: 'Edit Department',
                          onPressed: () => _openEditDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Department',
                          onPressed: () => _confirmDelete(context, dept),
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

  Widget _buildCellContent(String columnName, Department dept) {
    String value = '';
    TextStyle? style;

    switch (columnName) {
      case 'Organization Name':
        value = dept.organizationName;
        style = const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.active,
        );
        break;
      case 'Department Name':
        value = dept.departmentName;
        style = const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );
        break;
      case 'Department Head':
        value = dept.departmentHead;
        break;
      case 'Reporting Hierarchy':
        value = dept.reportingHierarchy;
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

  Widget _buildMobileList(List<Department> depts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: depts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dept = depts[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.active.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.domain_outlined,
                        color: AppColors.active,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dept.organizationName.isNotEmpty)
                            Text(
                              dept.organizationName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          Text(
                            dept.departmentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.remove_red_eye_outlined,
                              size: 18, color: AppColors.active),
                          tooltip: 'View Details',
                          onPressed: () => _openViewDialog(context, dept),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.active),
                          tooltip: 'Edit Department',
                          onPressed: () => _openEditDialog(context, dept),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'Delete Department',
                          onPressed: () => _confirmDelete(context, dept),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.active),
                    const SizedBox(width: 6),
                    const Text(
                      'Head: ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      dept.departmentHead.isEmpty ? '-' : dept.departmentHead,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (dept.workLocation.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              dept.workLocation,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    if (dept.reportingHierarchy.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.active.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined,
                                size: 12, color: AppColors.active),
                            const SizedBox(width: 4),
                            Text(
                              dept.reportingHierarchy,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.active,
                              ),
                            ),
                          ],
                        ),
                      ),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final showingText = Text(
            totalItems == 0
                ? 'Showing 0 records'
                : 'Showing ${startIndex + 1} - $endIndex of $totalItems',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          );

          final controlsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rows: ',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              DropdownButton<int>(
                value: _rowsPerPage,
                isDense: true,
                underline: const SizedBox(),
                items: [5, 10, 20, 50]
                    .map(
                      (val) => DropdownMenuItem(
                        value: val,
                        child: Text(
                          '$val',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _rowsPerPage = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 0
                    ? () => setState(() => _currentPage -= 1)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${totalPages == 0 ? 0 : currentPage + 1} / $totalPages',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: currentPage < totalPages - 1
                    ? () => setState(() => _currentPage += 1)
                    : null,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                showingText,
                const SizedBox(height: 4),
                controlsRow,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              showingText,
              controlsRow,
            ],
          );
        },
      ),
    );
  }
}
