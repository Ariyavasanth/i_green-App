import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/attendance_management_stats.dart';
import '../providers/attendance_management_providers.dart';
import 'widgets/admin_manual_attendance_dialog.dart';
import 'widgets/attendance_audit_dialog.dart';
import 'widgets/attendance_matrix_view.dart';
import 'widgets/attendance_table_view.dart';

class AttendanceManagementPage extends ConsumerStatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  ConsumerState<AttendanceManagementPage> createState() => _AttendanceManagementPageState();
}

enum AttendanceViewMode { matrix, table }

class _AttendanceManagementPageState extends ConsumerState<AttendanceManagementPage> {
  DateTime _focusedMonth = DateTime.now();
  int? _selectedEmployeeFilterId;
  String _selectedDepartmentFilter = 'All Departments';
  String _selectedDesignationFilter = 'All Designations';
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AttendanceViewMode _viewMode = AttendanceViewMode.matrix;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final monthYearStr = DateFormat('MM-yyyy').format(_focusedMonth);
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final employeesAsync = ref.watch(employeesProvider);
    final statsAsync = ref.watch(attendanceManagementStatsProvider(todayStr));
    final recordsAsync = ref.watch(
      attendanceManagementRecordsProvider((
        employeeId: _selectedEmployeeFilterId,
        monthYear: monthYearStr,
        statusFilter: _selectedStatusFilter,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            _buildHeader(context, isMobile),
            const SizedBox(height: 16),

            // Top Dashboard KPI Banner
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
              data: (stats) => _buildKpiBanner(stats, isMobile),
            ),
            const SizedBox(height: 16),

            // Controls & Filter Toolbar
            _buildControlToolbar(employeesAsync, isMobile),
            const SizedBox(height: 16),

            // Main Active View (Matrix vs Table)
            employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading employees: $e'),
              data: (employees) {
                return recordsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading attendance records: $e'),
                  data: (records) {
                    final filteredRecords = _filterRecords(records, employees);

                    if (_viewMode == AttendanceViewMode.matrix) {
                      return AttendanceMatrixView(
                        focusedMonth: _focusedMonth,
                        employees: _filterEmployees(employees),
                        records: filteredRecords,
                        onCellTap: (emp, dateStr, record) {
                          _openAdminEditDialog(
                            context,
                            record,
                            emp.id,
                            dateStr,
                          );
                        },
                      );
                    } else {
                      return AttendanceTableView(
                        records: filteredRecords,
                        onEdit: (record) => _openAdminEditDialog(context, record, record.employeeId, record.date),
                        onDelete: (record) => _handleDeleteRecord(record),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.co_present, size: 24, color: AppColors.active),
                  const SizedBox(width: 8),
                  const Text(
                    'Attendance Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done, size: 12, color: Color(0xFF2E7D32)),
                    SizedBox(width: 4),
                    Text(
                      'Firestore Sync',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openAdminEditDialog(context, null, null, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Manual Entry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFF414A51)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openAuditLogsDialog(context),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Audit Logs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF414A51),
                  side: const BorderSide(color: Color(0xFF414A51)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.push('/attendance-settings'),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Attendance Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.co_present, size: 26, color: AppColors.active),
        const SizedBox(width: 10),
        const Text(
          'Attendance Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF81C784)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done, size: 14, color: Color(0xFF2E7D32)),
              SizedBox(width: 4),
              Text(
                'Firestore Sync',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.active,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openAdminEditDialog(context, null, null, null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Manual Entry',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF414A51),
            side: const BorderSide(color: Color(0xFF414A51)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openAuditLogsDialog(context),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Audit Logs'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF414A51),
            side: const BorderSide(color: Color(0xFF414A51)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => context.push('/attendance-settings'),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Attendance Settings'),
        ),
      ],
    );
  }

  Widget _buildKpiBanner(AttendanceManagementStats stats, bool isMobile) {
    final items = [
      (
        title: 'Total Employees',
        value: stats.totalEmployees.toString(),
        icon: Icons.people_alt,
        color: const Color(0xFF414A51),
      ),
      (
        title: 'Present Today',
        value: (stats.presentToday + stats.checkedOutToday).toString(),
        icon: Icons.check_circle_outline,
        color: const Color(0xFF2E7D32),
      ),
      (
        title: 'Late Today',
        value: stats.lateToday.toString(),
        icon: Icons.running_with_errors,
        color: const Color(0xFFE65100),
      ),
      (
        title: 'Checked Out',
        value: stats.checkedOutToday.toString(),
        icon: Icons.logout,
        color: AppColors.active,
      ),
      (
        title: 'Absent / Pending',
        value: stats.absentToday.toString(),
        icon: Icons.event_busy,
        color: const Color(0xFFC62828),
      ),
    ];

    if (isMobile) {
      final cardWidth = (MediaQuery.of(context).size.width - 32 - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          return SizedBox(
            width: cardWidth,
            child: _kpiCard(
              title: item.title,
              value: item.value,
              icon: item.icon,
              color: item.color,
            ),
          );
        }).toList(),
      );
    }

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _kpiCard(
              title: item.title,
              value: item.value,
              icon: item.icon,
              color: item.color,
            ),
          ),
        );
      }).toList()..last = Expanded(
        child: _kpiCard(
          title: items.last.title,
          value: items.last.value,
          icon: items.last.icon,
          color: items.last.color,
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlToolbar(AsyncValue<List<Employee>> employeesAsync, bool isMobile) {
    final monthSelector = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.active),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedMonth),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.active),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
        ),
      ],
    );

    final segmentedButton = SegmentedButton<AttendanceViewMode>(
      style: ButtonStyle(
        visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
      ),
      segments: const [
        ButtonSegment(
          value: AttendanceViewMode.matrix,
          icon: Icon(Icons.grid_on, size: 16),
          label: Text('Matrix Heatmap'),
        ),
        ButtonSegment(
          value: AttendanceViewMode.table,
          icon: Icon(Icons.table_chart, size: 16),
          label: Text('Detailed Log Table'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) => setState(() => _viewMode = set.first),
    );

    final allEmployeesList = employeesAsync.valueOrNull ?? [];

    final departmentList = [
      'All Departments',
      ...{
        ...Employee.departmentOptions,
        ...allEmployeesList.map((e) => e.department).where((d) => d.trim().isNotEmpty),
      }
    ];

    final designationList = [
      'All Designations',
      ...{
        ...Employee.designationOptions,
        ...allEmployeesList.map((e) => e.designation).where((d) => d.trim().isNotEmpty),
      }
    ];

    final departmentField = _SearchableFilterField<String>(
      labelText: 'Filter Department',
      valueText: _selectedDepartmentFilter,
      isSelected: _selectedDepartmentFilter != 'All Departments',
      items: departmentList.where((d) => d != 'All Departments').toList(),
      itemLabel: (d) => d,
      allLabel: 'All Departments',
      icon: Icons.business,
      onSelected: (val) {
        setState(() {
          _selectedDepartmentFilter = val ?? 'All Departments';
          if (_selectedEmployeeFilterId != null) {
            final selectedEmp = allEmployeesList.where((e) => e.id == _selectedEmployeeFilterId).firstOrNull;
            if (selectedEmp != null && _selectedDepartmentFilter != 'All Departments' && selectedEmp.department != _selectedDepartmentFilter) {
              _selectedEmployeeFilterId = null;
            }
          }
        });
      },
    );

    final designationField = _SearchableFilterField<String>(
      labelText: 'Filter Designation',
      valueText: _selectedDesignationFilter,
      isSelected: _selectedDesignationFilter != 'All Designations',
      items: designationList.where((d) => d != 'All Designations').toList(),
      itemLabel: (d) => d,
      allLabel: 'All Designations',
      icon: Icons.work_outline,
      onSelected: (val) {
        setState(() {
          _selectedDesignationFilter = val ?? 'All Designations';
          if (_selectedEmployeeFilterId != null) {
            final selectedEmp = allEmployeesList.where((e) => e.id == _selectedEmployeeFilterId).firstOrNull;
            if (selectedEmp != null && _selectedDesignationFilter != 'All Designations' && selectedEmp.designation != _selectedDesignationFilter) {
              _selectedEmployeeFilterId = null;
            }
          }
        });
      },
    );

    final availableEmployeesForDropdown = allEmployeesList.where((e) {
      if (_selectedDepartmentFilter != 'All Departments' && e.department != _selectedDepartmentFilter) {
        return false;
      }
      if (_selectedDesignationFilter != 'All Designations' && e.designation != _selectedDesignationFilter) {
        return false;
      }
      return true;
    }).toList();

    final selectedEmpObj = availableEmployeesForDropdown.where((e) => e.id == _selectedEmployeeFilterId).firstOrNull;
    final employeeField = _SearchableFilterField<Employee>(
      labelText: 'Filter Employee',
      valueText: selectedEmpObj != null ? selectedEmpObj.fullName : 'All Employees',
      isSelected: _selectedEmployeeFilterId != null,
      items: availableEmployeesForDropdown,
      itemLabel: (e) => e.fullName,
      itemSubLabel: (e) => [
        if (e.employeeId.isNotEmpty) e.employeeId,
        if (e.designation.isNotEmpty) e.designation,
        if (e.department.isNotEmpty) e.department,
      ].join(' • '),
      allLabel: 'All Employees',
      icon: Icons.person_search,
      onSelected: (emp) {
        setState(() => _selectedEmployeeFilterId = emp?.id);
      },
    );

    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedStatusFilter,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Status',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'Present', child: Text('Present', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'Late', child: Text('Late', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'Checked Out', child: Text('Checked Out', style: TextStyle(fontSize: 12))),
        DropdownMenuItem(value: 'Absent', child: Text('Absent', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedStatusFilter = val);
      },
    );

    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search employee name or date...',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
    );

    final isAnyFilterActive = _selectedDepartmentFilter != 'All Departments' ||
        _selectedDesignationFilter != 'All Designations' ||
        _selectedEmployeeFilterId != null ||
        _selectedStatusFilter != 'All' ||
        _searchQuery.isNotEmpty;

    final clearFiltersButton = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isAnyFilterActive ? const Color(0xFFD32F2F) : AppColors.textSecondary,
        backgroundColor: isAnyFilterActive ? const Color(0xFFFFEBEE) : Colors.white,
        side: BorderSide(
          color: isAnyFilterActive ? const Color(0xFFEF5350) : const Color(0xFFCBD5E1),
          width: isAnyFilterActive ? 1.5 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.filter_alt_off,
        size: 16,
        color: isAnyFilterActive ? const Color(0xFFD32F2F) : AppColors.textSecondary,
      ),
      label: Text(
        'Clear Filters',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isAnyFilterActive ? const Color(0xFFD32F2F) : AppColors.textSecondary,
        ),
      ),
      onPressed: () {
        setState(() {
          _selectedDepartmentFilter = 'All Departments';
          _selectedDesignationFilter = 'All Designations';
          _selectedEmployeeFilterId = null;
          _selectedStatusFilter = 'All';
          _searchQuery = '';
          _searchController.clear();
        });
      },
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: segmentedButton,
                ),
                const SizedBox(height: 8),
                monthSelector,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                departmentField,
                const SizedBox(height: 14),
                designationField,
                const SizedBox(height: 14),
                employeeField,
                const SizedBox(height: 14),
                statusDropdown,
                const SizedBox(height: 14),
                searchField,
                const SizedBox(height: 14),
                clearFiltersButton,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    segmentedButton,
                    const Spacer(),
                    monthSelector,
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 175, child: departmentField),
                    SizedBox(width: 175, child: designationField),
                    SizedBox(width: 185, child: employeeField),
                    SizedBox(width: 140, child: statusDropdown),
                    SizedBox(width: 220, child: searchField),
                    clearFiltersButton,
                  ],
                ),
              ],
            ),
    );
  }

  List<Employee> _filterEmployees(List<Employee> employees) {
    return employees.where((e) {
      if (_selectedDepartmentFilter != 'All Departments' && e.department != _selectedDepartmentFilter) {
        return false;
      }
      if (_selectedDesignationFilter != 'All Designations' && e.designation != _selectedDesignationFilter) {
        return false;
      }
      if (_selectedEmployeeFilterId != null && e.id != _selectedEmployeeFilterId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = e.fullName.toLowerCase().contains(q);
        final matchDept = e.department.toLowerCase().contains(q);
        final matchDesig = e.designation.toLowerCase().contains(q);
        if (!matchName && !matchDept && !matchDesig) return false;
      }
      return true;
    }).toList();
  }

  List<AttendanceRecord> _filterRecords(List<AttendanceRecord> records, List<Employee> employees) {
    final filteredEmployeeIds = _filterEmployees(employees).map((e) => e.id).toSet();

    return records.where((rec) {
      if (!filteredEmployeeIds.contains(rec.employeeId)) {
        return false;
      }
      if (_selectedStatusFilter != 'All' && rec.status != _selectedStatusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchName = rec.employeeName.toLowerCase().contains(_searchQuery);
        final matchDate = rec.date.toLowerCase().contains(_searchQuery);
        if (!matchName && !matchDate) return false;
      }
      return true;
    }).toList();
  }

  void _openAdminEditDialog(
    BuildContext context,
    AttendanceRecord? record,
    int? employeeId,
    String? dateStr,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AdminManualAttendanceDialog(
        existingRecord: record,
        initialEmployeeId: employeeId,
        initialDate: dateStr,
        onSaved: () => _refreshAll(),
      ),
    );
  }

  void _openAuditLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AttendanceAuditDialog(employeeId: _selectedEmployeeFilterId),
    );
  }

  Future<void> _handleDeleteRecord(AttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Firestore Attendance Record'),
        content: Text('Are you sure you want to delete attendance for ${record.employeeName} on ${record.date} from Firestore?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(attendanceManagementRepositoryProvider).deleteAttendanceRecord(
            record.employeeId,
            record.date,
          );
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance record deleted from Firestore.')),
        );
      }
    }
  }

  void _refreshAll() {
    final monthYearStr = DateFormat('MM-yyyy').format(_focusedMonth);
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    ref.invalidate(attendanceManagementStatsProvider(todayStr));
    ref.invalidate(attendanceManagementRecordsProvider((
      employeeId: _selectedEmployeeFilterId,
      monthYear: monthYearStr,
      statusFilter: _selectedStatusFilter,
    )));
  }
}

class _SearchableFilterField<T> extends StatelessWidget {
  final String labelText;
  final String valueText;
  final bool isSelected;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T)? itemSubLabel;
  final ValueChanged<T?> onSelected;
  final String allLabel;
  final IconData icon;

  const _SearchableFilterField({
    required this.labelText,
    required this.valueText,
    required this.isSelected,
    required this.items,
    required this.itemLabel,
    this.itemSubLabel,
    required this.onSelected,
    required this.allLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSearchDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.active, width: 2),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                IconButton(
                  icon: const Icon(Icons.cancel, size: 16, color: AppColors.textSecondary),
                  tooltip: 'Clear filter',
                  onPressed: () => onSelected(null),
                ),
              const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
          ),
        ),
        child: Text(
          valueText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.active : AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  void _openSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = items.where((item) {
              final label = itemLabel(item).toLowerCase();
              final sub = itemSubLabel != null ? itemSubLabel!(item).toLowerCase() : '';
              final q = query.toLowerCase().trim();
              return label.contains(q) || sub.contains(q);
            }).toList();

            final screenWidth = MediaQuery.of(context).size.width;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: AppColors.active),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select $labelText',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.pop(dialogCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search $labelText...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.active, width: 2),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        query = val;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: screenWidth < 400 ? (screenWidth - 64).clamp(240.0, 360.0) : 360,
                height: 320,
                child: Column(
                  children: [
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      tileColor: !isSelected ? AppColors.active.withValues(alpha: 0.1) : null,
                      leading: const Icon(Icons.select_all, size: 18),
                      title: Text(
                        allLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: !isSelected ? FontWeight.bold : FontWeight.normal,
                          color: !isSelected ? AppColors.active : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: !isSelected ? const Icon(Icons.check_circle, size: 18, color: AppColors.active) : null,
                      onTap: () {
                        onSelected(null);
                        Navigator.pop(dialogCtx);
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No options match your search', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final item = filtered[index];
                                final label = itemLabel(item);
                                final isCurrent = isSelected && valueText == label;
                                final sub = itemSubLabel != null ? itemSubLabel!(item) : null;

                                return ListTile(
                                  dense: true,
                                  tileColor: isCurrent ? AppColors.active.withValues(alpha: 0.1) : null,
                                  title: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? AppColors.active : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: sub != null && sub.isNotEmpty
                                      ? Text(
                                          sub,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  trailing: isCurrent ? const Icon(Icons.check_circle, size: 18, color: AppColors.active) : null,
                                  onTap: () {
                                    onSelected(item);
                                    Navigator.pop(dialogCtx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
