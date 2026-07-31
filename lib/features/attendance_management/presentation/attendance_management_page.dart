import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  AttendanceViewMode _viewMode = AttendanceViewMode.matrix;

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
                    final filteredRecords = _filterRecords(records);

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
          Row(
            children: [
              const Icon(Icons.co_present, size: 24, color: AppColors.active),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Attendance Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
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
      return SizedBox(
        height: 82,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 165,
              child: _kpiCard(
                title: item.title,
                value: item.value,
                icon: item.icon,
                color: item.color,
              ),
            );
          },
        ),
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

    final employeeDropdown = employeesAsync.maybeWhen(
      data: (employees) => DropdownButtonFormField<int?>(
        initialValue: _selectedEmployeeFilterId,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'Filter Employee',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All Employees', style: TextStyle(fontSize: 12)),
          ),
          ...employees.map((e) => DropdownMenuItem<int?>(
                value: e.id,
                child: Text(e.fullName, style: const TextStyle(fontSize: 12)),
              )),
        ],
        onChanged: (val) => setState(() => _selectedEmployeeFilterId = val),
      ),
      orElse: () => const SizedBox.shrink(),
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
      decoration: InputDecoration(
        hintText: 'Search employee name or date...',
        prefixIcon: const Icon(Icons.search, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
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
                employeeDropdown,
                const SizedBox(height: 10),
                statusDropdown,
                const SizedBox(height: 10),
                searchField,
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    segmentedButton,
                    const Spacer(),
                    monthSelector,
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(width: 220, child: employeeDropdown),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: statusDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: searchField),
                  ],
                ),
              ],
            ),
    );
  }

  List<Employee> _filterEmployees(List<Employee> employees) {
    if (_selectedEmployeeFilterId != null) {
      return employees.where((e) => e.id == _selectedEmployeeFilterId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      return employees.where((e) => e.fullName.toLowerCase().contains(_searchQuery)).toList();
    }
    return employees;
  }

  List<AttendanceRecord> _filterRecords(List<AttendanceRecord> records) {
    return records.where((rec) {
      if (_selectedEmployeeFilterId != null && rec.employeeId != _selectedEmployeeFilterId) {
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
