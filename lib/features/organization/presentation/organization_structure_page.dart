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
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => _openAddDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.add),
              label: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          _buildToolbar(context, prefAsync, isMobile),
          const Divider(height: 1, color: Color(0xFFEAECF0)),
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
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
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
                            ref.read(deptSearchQueryProvider.notifier).state = '';
                            setState(() => _currentPage = 0);
                          },
                        ),
                      const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF667085)),
                      const SizedBox(width: 8),
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
          if (!isMobile) ...[
            const SizedBox(width: 10),
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
                'Add Department',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAddDialog(BuildContext context) {
    DepartmentFormDialog.show(context);
  }

  void _openEditDialog(BuildContext context, Department dept) {
    DepartmentFormDialog.show(context, department: dept);
  }

  void _openViewDialog(BuildContext context, Department dept) {
    showDialog<void>(
      context: context,
      builder: (context) => DepartmentDetailsDialog(department: dept),
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
      await ref.read(organizationRepositoryProvider).deleteDepartment(dept.id);
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
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'View Details',
                          onPressed: () => _openViewDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'Edit Department',
                          onPressed: () => _openEditDialog(context, dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
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
        style = const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF667085));
        break;
      case 'Department Name':
        value = dept.departmentName;
        style = const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF101828), fontSize: 14);
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
                    // Neutral light gray icon container
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
                          // Primary bold Department Name title (18px)
                          Text(
                            dept.departmentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtle metadata company name
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
                          if (val == 'view') _openViewDialog(context, dept);
                          if (val == 'edit') _openEditDialog(context, dept);
                          if (val == 'delete') _confirmDelete(context, dept);
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Location Pill - Subtle blue tint
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
                    // Role Pill - Subtle violet tint
                    if (dept.reportingHierarchy.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF9333EA)),
                            const SizedBox(width: 4),
                            Text(
                              dept.reportingHierarchy,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B21A8), fontWeight: FontWeight.w600),
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
