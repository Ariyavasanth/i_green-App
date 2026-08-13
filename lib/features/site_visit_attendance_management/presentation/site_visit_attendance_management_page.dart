import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../attendance_management/domain/attendance_management_stats.dart';
import '../../attendance_management/presentation/widgets/admin_manual_attendance_dialog.dart';
import '../../attendance_management/presentation/widgets/attendance_audit_dialog.dart';
import '../../attendance_management/presentation/widgets/attendance_matrix_view.dart';
import '../../attendance_management/presentation/widgets/attendance_table_view.dart';
import '../../attendance_management/providers/attendance_management_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../providers/site_visit_attendance_management_providers.dart';

class SiteVisitAttendanceManagementPage extends ConsumerStatefulWidget {
  const SiteVisitAttendanceManagementPage({super.key});

  @override
  ConsumerState<SiteVisitAttendanceManagementPage> createState() =>
      _SiteVisitAttendanceManagementPageState();
}

enum SiteVisitViewMode { matrix, table }
enum AttendanceCategory { siteVisit, staticVisit }

class _SiteVisitAttendanceManagementPageState
    extends ConsumerState<SiteVisitAttendanceManagementPage> {
  DateTime _focusedMonth = DateTime.now();
  int? _selectedEmployeeId;
  String _selectedDepartment = 'All Departments';
  String _selectedDesignation = 'All Designations';
  String _selectedStatus = 'All';
  String _selectedSite = 'All';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  SiteVisitViewMode _viewMode = SiteVisitViewMode.matrix;
  AttendanceCategory _category = AttendanceCategory.siteVisit;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final isSite = _category == AttendanceCategory.siteVisit;

    // Site Visits Async
    final visitsAsync = isSite
        ? ref.watch(allSiteVisitsProvider((visitDate: null, employeeId: null, siteName: null)))
        : const AsyncValue<List<SiteVisitRecord>>.data([]);

    // Static Visits Async
    final monthYearStr = DateFormat('MM-yyyy').format(_focusedMonth);
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final staticRecordsAsync = !isSite
        ? ref.watch(attendanceManagementRecordsProvider((
            employeeId: _selectedEmployeeId,
            monthYear: monthYearStr,
            statusFilter: _selectedStatus,
          )))
        : const AsyncValue<List<AttendanceRecord>>.data([]);

    final staticStatsAsync = !isSite
        ? ref.watch(attendanceManagementStatsProvider(todayStr))
        : const AsyncValue<AttendanceManagementStats>.loading();

    final allEmployeesList = ref.watch(employeesProvider).valueOrNull ?? [];

    Widget kpiWidget;
    Widget toolbarWidget;
    Widget mainViewWidget;

    if (isSite) {
      kpiWidget = visitsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const SizedBox.shrink(),
        data: (visits) => _buildKpiBanner(_filterVisits(visits, allEmployeesList), isMobile),
      );

      toolbarWidget = visitsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const SizedBox.shrink(),
        data: (visits) => _buildControlToolbar(visits, allEmployeesList, isMobile),
      );

      mainViewWidget = visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error loading site visits: $e'),
        data: (visits) {
          final filtered = _filterVisits(visits, allEmployeesList);
          if (_viewMode == SiteVisitViewMode.matrix) {
            return _SiteVisitMatrixView(
              focusedMonth: _focusedMonth,
              visits: filtered,
              onCellTap: (employeeName, dateStr, dayVisits) {
                _openDayTimelineDialog(context, employeeName, dateStr, dayVisits);
              },
            );
          }
          return _DetailedSiteVisitLogTable(
            groupedVisits: _groupVisits(filtered),
            onDelete: _handleDeleteRecord,
            onLocationTap: _openMap,
            onPhotoTap: _openPhotoPreview,
          );
        },
      );
    } else {
      kpiWidget = staticStatsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => const SizedBox.shrink(),
        data: (stats) => _buildKpiBannerForStatic(stats, isMobile),
      );

      toolbarWidget = _buildControlToolbarForStatic(allEmployeesList, isMobile);

      mainViewWidget = staticRecordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error loading attendance records: $e'),
        data: (records) {
          final filteredRecords = _filterStaticRecords(records, allEmployeesList);
          final filteredEmployees = _filterEmployeesForStatic(allEmployeesList);

          if (_viewMode == SiteVisitViewMode.matrix) {
            return AttendanceMatrixView(
              focusedMonth: _focusedMonth,
              employees: filteredEmployees,
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
              onDelete: (record) => _handleDeleteRecordForStatic(record),
            );
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 16),
            kpiWidget,
            const SizedBox(height: 16),
            toolbarWidget,
            const SizedBox(height: 16),
            mainViewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    const activeColor = Color(0xFF9CC70A);
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: activeColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF414A51),
      side: const BorderSide(color: Color(0xFF414A51)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    final titleRow = Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 26, color: Color(0xFF9CC70A)),
        const SizedBox(width: 10),
        const Text(
          'Site visit management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (!isMobile) ...[
          const Spacer(),
          ..._buildActionButtons(buttonStyle, outlinedStyle),
        ],
      ],
    );

    final toggleRow = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: SegmentedButton<AttendanceCategory>(
          segments: const [
            ButtonSegment(
              value: AttendanceCategory.siteVisit,
              icon: Icon(Icons.explore_outlined, size: 16),
              label: Text('Site Visits', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: AttendanceCategory.staticVisit,
              icon: Icon(Icons.home_work_outlined, size: 16),
              label: Text('Static Visits', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_category},
          onSelectionChanged: (set) {
            setState(() {
              _category = set.first;
              // Reset filters when switching categories
              _selectedStatus = 'All';
              _selectedEmployeeId = null;
              _selectedDepartment = 'All Departments';
              _selectedDesignation = 'All Designations';
              _selectedSite = 'All';
              _search = '';
              _searchController.clear();
            });
          },
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 24, color: Color(0xFF9CC70A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Site visit management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          toggleRow,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActionButtons(buttonStyle, outlinedStyle).toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
        const SizedBox(height: 8),
        toggleRow,
      ],
    );
  }

  List<Widget> _buildActionButtons(ButtonStyle buttonStyle, ButtonStyle outlinedStyle) {
    if (_category == AttendanceCategory.siteVisit) {
      return [
        ElevatedButton.icon(
          style: buttonStyle,
          onPressed: _openManualSiteVisitDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            '+ Add Site Visit',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: outlinedStyle,
          onPressed: _openAuditLogsDialog,
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Audit Logs'),
        ),
      ];
    } else {
      return [
        ElevatedButton.icon(
          style: buttonStyle,
          onPressed: () => _openAdminEditDialog(context, null, null, null),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Manual Entry',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: outlinedStyle,
          onPressed: () => _openAuditLogsDialogForStatic(context),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Audit Logs'),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: outlinedStyle,
          onPressed: () => context.push('/attendance-settings'),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Attendance Settings'),
        ),
      ];
    }
  }

  Widget _buildKpiBannerForStatic(AttendanceManagementStats stats, bool isMobile) {
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
        color: const Color(0xFF9CC70A),
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

  Widget _buildControlToolbarForStatic(List<Employee> allEmployees, bool isMobile) {
    final departmentList = [
      'All Departments',
      ...{
        ...Employee.departmentOptions,
        ...allEmployees.map((e) => e.department).where((d) => d.trim().isNotEmpty),
      }
    ];

    final designationList = [
      'All Designations',
      ...{
        ...Employee.designationOptions,
        ...allEmployees.map((e) => e.designation).where((d) => d.trim().isNotEmpty),
      }
    ];

    final departmentDropdown = DropdownButtonFormField<String>(
      initialValue: departmentList.contains(_selectedDepartment) ? _selectedDepartment : 'All Departments',
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Department',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: departmentList
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedDepartment = val;
            if (_selectedEmployeeId != null) {
              final selectedEmp = allEmployees.where((e) => e.id == _selectedEmployeeId).firstOrNull;
              if (selectedEmp != null && _selectedDepartment != 'All Departments' && selectedEmp.department != _selectedDepartment) {
                _selectedEmployeeId = null;
              }
            }
          });
        }
      },
    );

    final designationDropdown = DropdownButtonFormField<String>(
      initialValue: designationList.contains(_selectedDesignation) ? _selectedDesignation : 'All Designations',
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Designation',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: designationList
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedDesignation = val;
            if (_selectedEmployeeId != null) {
              final selectedEmp = allEmployees.where((e) => e.id == _selectedEmployeeId).firstOrNull;
              if (selectedEmp != null && _selectedDesignation != 'All Designations' && selectedEmp.designation != _selectedDesignation) {
                _selectedEmployeeId = null;
              }
            }
          });
        }
      },
    );

    final availableEmployees = allEmployees.where((emp) {
      if (_selectedDepartment != 'All Departments' && emp.department != _selectedDepartment) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' && emp.designation != _selectedDesignation) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));

    final monthSelector = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF9CC70A)),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedMonth),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Color(0xFF9CC70A)),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
        ),
      ],
    );

    final segmentedButton = SegmentedButton<SiteVisitViewMode>(
      style: const ButtonStyle(visualDensity: VisualDensity.standard),
      segments: const [
        ButtonSegment(
          value: SiteVisitViewMode.matrix,
          icon: Icon(Icons.grid_on, size: 16),
          label: Text('Matrix Heatmap'),
        ),
        ButtonSegment(
          value: SiteVisitViewMode.table,
          icon: Icon(Icons.table_chart, size: 16),
          label: Text('Detailed Log Table'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) => setState(() => _viewMode = set.first),
    );

    final employeeDropdown = DropdownButtonFormField<int?>(
      initialValue: availableEmployees.any((e) => e.id == _selectedEmployeeId) ? _selectedEmployeeId : null,
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
        ...availableEmployees.map(
          (e) => DropdownMenuItem<int?>(
            value: e.id,
            child: Text(e.fullName, style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (val) => setState(() => _selectedEmployeeId = val),
    );

    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedStatus,
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
        if (val != null) setState(() => _selectedStatus = val);
      },
    );

    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search employee or date',
        prefixIcon: const Icon(Icons.search, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
    );

    final clearFiltersButton = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC62828),
        side: const BorderSide(color: Color(0xFFC62828)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.filter_alt_off, size: 16),
      label: const Text('Clear Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      onPressed: () {
        setState(() {
          _selectedDepartment = 'All Departments';
          _selectedDesignation = 'All Designations';
          _selectedEmployeeId = null;
          _selectedStatus = 'All';
          _search = '';
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
                FittedBox(fit: BoxFit.scaleDown, child: segmentedButton),
                const SizedBox(height: 8),
                monthSelector,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                departmentDropdown,
                const SizedBox(height: 10),
                designationDropdown,
                const SizedBox(height: 10),
                employeeDropdown,
                const SizedBox(height: 10),
                statusDropdown,
                const SizedBox(height: 10),
                searchField,
                const SizedBox(height: 10),
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
                    SizedBox(width: 170, child: departmentDropdown),
                    SizedBox(width: 170, child: designationDropdown),
                    SizedBox(width: 170, child: employeeDropdown),
                    SizedBox(width: 140, child: statusDropdown),
                    SizedBox(width: 220, child: searchField),
                    clearFiltersButton,
                  ],
                ),
              ],
            ),
    );
  }

  List<Employee> _filterEmployeesForStatic(List<Employee> employees) {
    return employees.where((e) {
      if (_selectedDepartment != 'All Departments' && e.department != _selectedDepartment) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' && e.designation != _selectedDesignation) {
        return false;
      }
      if (_selectedEmployeeId != null && e.id != _selectedEmployeeId) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final matchName = e.fullName.toLowerCase().contains(q);
        final matchDept = e.department.toLowerCase().contains(q);
        final matchDesig = e.designation.toLowerCase().contains(q);
        if (!matchName && !matchDept && !matchDesig) return false;
      }
      return true;
    }).toList();
  }

  List<AttendanceRecord> _filterStaticRecords(List<AttendanceRecord> records, List<Employee> employees) {
    final filteredEmployeeIds = _filterEmployeesForStatic(employees).map((e) => e.id).toSet();

    return records.where((rec) {
      if (!filteredEmployeeIds.contains(rec.employeeId)) {
        return false;
      }
      if (_selectedStatus != 'All' && rec.status != _selectedStatus) {
        return false;
      }
      if (_search.isNotEmpty) {
        final matchName = rec.employeeName.toLowerCase().contains(_search);
        final matchDate = rec.date.toLowerCase().contains(_search);
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

  void _openAuditLogsDialogForStatic(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AttendanceAuditDialog(employeeId: _selectedEmployeeId),
    );
  }

  Future<void> _handleDeleteRecordForStatic(AttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attendance Record'),
        content: Text('Are you sure you want to delete attendance for ${record.employeeName} on ${record.date}?'),
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
          const SnackBar(content: Text('Attendance record deleted.')),
        );
      }
    }
  }

  void _refreshAll() {
    if (_category == AttendanceCategory.siteVisit) {
      ref.invalidate(allSiteVisitsProvider((visitDate: null, employeeId: null, siteName: null)));
    } else {
      final monthYearStr = DateFormat('MM-yyyy').format(_focusedMonth);
      final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
      ref.invalidate(attendanceManagementStatsProvider(todayStr));
      ref.invalidate(attendanceManagementRecordsProvider((
        employeeId: _selectedEmployeeId,
        monthYear: monthYearStr,
        statusFilter: _selectedStatus,
      )));
    }
  }

  Widget _buildKpiBanner(List<SiteVisitRecord> visits, bool isMobile) {
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final totalSites = visits.map((v) => v.siteName.trim()).where((e) => e.isNotEmpty).toSet().length;
    final visitsToday = visits.where((v) => v.visitDate == today).length;
    final totalEmployees = visits.map((v) => v.employeeId).toSet().length;

    final items = [
      (
        title: 'Total Sites',
        value: totalSites.toString(),
        icon: Icons.location_city_outlined,
        color: const Color(0xFF414A51),
      ),
      (
        title: 'Visits Today',
        value: visitsToday.toString(),
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF2E7D32),
      ),
      (
        title: 'Employees Visited',
        value: totalEmployees.toString(),
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF9CC70A),
      ),
      (
        title: 'Late',
        value: visits.where((v) => _statusForVisit(v) == 'Late').length.toString(),
        icon: Icons.running_with_errors,
        color: const Color(0xFFE65100),
      ),
      (
        title: 'Checked Out',
        value: visits.where((v) => _statusForVisit(v) == 'Checked out').length.toString(),
        icon: Icons.logout,
        color: const Color(0xFF414A51),
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
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 10),
              child: _kpiCard(
                title: items[i].title,
                value: items[i].value,
                icon: items[i].icon,
                color: items[i].color,
              ),
            ),
          ),
        ],
      ],
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
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlToolbar(List<SiteVisitRecord> visits, List<Employee> allEmployees, bool isMobile) {
    final empMap = {for (final e in allEmployees) e.id: e};

    final departmentList = [
      'All Departments',
      ...{
        ...Employee.departmentOptions,
        ...allEmployees.map((e) => e.department).where((d) => d.trim().isNotEmpty),
      }
    ];

    final designationList = [
      'All Designations',
      ...{
        ...Employee.designationOptions,
        ...allEmployees.map((e) => e.designation).where((d) => d.trim().isNotEmpty),
      }
    ];

    final departmentDropdown = DropdownButtonFormField<String>(
      initialValue: departmentList.contains(_selectedDepartment) ? _selectedDepartment : 'All Departments',
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Department',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: departmentList
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedDepartment = val);
      },
    );

    final designationDropdown = DropdownButtonFormField<String>(
      initialValue: designationList.contains(_selectedDesignation) ? _selectedDesignation : 'All Designations',
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Designation',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: designationList
          .map((d) => DropdownMenuItem<String>(
                value: d,
                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedDesignation = val);
      },
    );

    final employees = visits.map((v) => MapEntry(v.employeeId, v.employeeName)).toSet().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final availableEmployees = employees.where((entry) {
      final emp = empMap[entry.key];
      if (_selectedDepartment != 'All Departments' && (emp == null || emp.department != _selectedDepartment)) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' && (emp == null || emp.designation != _selectedDesignation)) {
        return false;
      }
      return true;
    }).toList();

    final sites = visits.map((v) => v.siteName.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();

    final monthSelector = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF9CC70A)),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_focusedMonth),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Color(0xFF9CC70A)),
          onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
        ),
      ],
    );

    final segmentedButton = SegmentedButton<SiteVisitViewMode>(
      style: const ButtonStyle(visualDensity: VisualDensity.standard),
      segments: const [
        ButtonSegment(
          value: SiteVisitViewMode.matrix,
          icon: Icon(Icons.grid_on, size: 16),
          label: Text('Matrix Heatmap'),
        ),
        ButtonSegment(
          value: SiteVisitViewMode.table,
          icon: Icon(Icons.table_chart, size: 16),
          label: Text('Detailed Log Table'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) => setState(() => _viewMode = set.first),
    );

    final employeeDropdown = DropdownButtonFormField<int?>(
      initialValue: availableEmployees.any((e) => e.key == _selectedEmployeeId) ? _selectedEmployeeId : null,
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
        ...availableEmployees.map(
          (e) => DropdownMenuItem<int?>(
            value: e.key,
            child: Text(e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (val) => setState(() => _selectedEmployeeId = val),
    );

    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedStatus,
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
        DropdownMenuItem(value: 'Checked out', child: Text('Checked Out', style: TextStyle(fontSize: 12))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedStatus = val);
      },
    );

    final siteDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedSite,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Filter Site',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        const DropdownMenuItem(value: 'All', child: Text('All Sites', style: TextStyle(fontSize: 12))),
        ...sites.map((site) => DropdownMenuItem(value: site, child: Text(site, style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedSite = val);
      },
    );

    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search site, employee or date',
        prefixIcon: const Icon(Icons.search, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
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
                FittedBox(fit: BoxFit.scaleDown, child: segmentedButton),
                const SizedBox(height: 8),
                monthSelector,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(height: 1),
                ),
                departmentDropdown,
                const SizedBox(height: 10),
                designationDropdown,
                const SizedBox(height: 10),
                employeeDropdown,
                const SizedBox(height: 10),
                statusDropdown,
                const SizedBox(height: 10),
                siteDropdown,
                const SizedBox(height: 10),
                searchField,
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
                    SizedBox(width: 170, child: departmentDropdown),
                    SizedBox(width: 170, child: designationDropdown),
                    SizedBox(width: 170, child: employeeDropdown),
                    SizedBox(width: 140, child: statusDropdown),
                    SizedBox(width: 160, child: siteDropdown),
                    SizedBox(width: 220, child: searchField),
                  ],
                ),
              ],
            ),
    );
  }

  List<SiteVisitRecord> _filterVisits(List<SiteVisitRecord> visits, List<Employee> allEmployees) {
    final empMap = {for (final e in allEmployees) e.id: e};
    final focusedMonth = DateFormat('MM-yyyy').format(_focusedMonth);
    return visits.where((visit) {
      if (visit.visitDate.isNotEmpty && !visit.visitDate.endsWith(focusedMonth)) {
        return false;
      }
      final emp = empMap[visit.employeeId];
      if (_selectedDepartment != 'All Departments' && (emp == null || emp.department != _selectedDepartment)) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' && (emp == null || emp.designation != _selectedDesignation)) {
        return false;
      }
      if (_selectedEmployeeId != null && visit.employeeId != _selectedEmployeeId) {
        return false;
      }
      if (_selectedSite != 'All' && visit.siteName != _selectedSite) {
        return false;
      }
      if (_selectedStatus != 'All' && _statusForVisit(visit) != _selectedStatus) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search;
        final matchEmployee = visit.employeeName.toLowerCase().contains(q);
        final matchSite = visit.siteName.toLowerCase().contains(q);
        final matchDate = visit.visitDate.toLowerCase().contains(q) || visit.visitTime.toLowerCase().contains(q);
        final matchDept = emp != null && emp.department.toLowerCase().contains(q);
        final matchDesig = emp != null && emp.designation.toLowerCase().contains(q);
        if (!matchEmployee && !matchSite && !matchDate && !matchDept && !matchDesig) return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<SiteVisitRecord>> _groupVisits(List<SiteVisitRecord> visits) {
    final grouped = <String, List<SiteVisitRecord>>{};
    for (final visit in visits) {
      final key = '${visit.employeeId}_${visit.visitDate}';
      grouped.putIfAbsent(key, () => []).add(visit);
    }
    for (final group in grouped.values) {
      group.sort((a, b) => b.visitTime.compareTo(a.visitTime));
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          final aFirst = a.value.first;
          final bFirst = b.value.first;
          final byDate = bFirst.visitDate.compareTo(aFirst.visitDate);
          if (byDate != 0) return byDate;
          return bFirst.visitTime.compareTo(aFirst.visitTime);
        }),
    );
  }

  String _statusForVisit(SiteVisitRecord visit) {
    final time = visit.visitTime.trim();
    if (time.isEmpty) return 'Present';
    final parsed = _tryParseTime(time);
    if (parsed == null) return 'Present';
    if (parsed.hour >= 17) return 'Checked out';
    if (parsed.hour >= 10) return 'Late';
    return 'Present';
  }

  DateTime? _tryParseTime(String value) {
    final formats = [DateFormat('hh:mm a'), DateFormat('HH:mm'), DateFormat('hh:mm:ss a')];
    for (final format in formats) {
      try {
        return format.parse(value);
      } catch (_) {}
    }
    return null;
  }

  void _openManualSiteVisitDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual site visit entry can be wired here.')),
    );
  }

  void _openAuditLogsDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audit logs can be wired here.')),
    );
  }

  void _openDayTimelineDialog(
    BuildContext context,
    String employeeName,
    String dateStr,
    List<SiteVisitRecord> dayVisits,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$employeeName - $dateStr'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: dayVisits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _DetailedVisitTile(
              visit: dayVisits[index],
              onLocationTap: _openMap,
              onPhotoTap: _openPhotoPreview,
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _openMap(SiteVisitRecord visit) async {
    final query = Uri.encodeComponent('${visit.latitude},${visit.longitude}');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPhotoPreview(String photoUrl) async {
    if (photoUrl.isEmpty) return;
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: InteractiveViewer(
          child: Image.network(photoUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _handleDeleteRecord(SiteVisitRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Site Visit'),
        content: Text('Are you sure you want to delete site visit for ${record.employeeName} on ${record.visitDate}?'),
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
      await ref.read(siteVisitAttendanceManagementRepositoryProvider).deleteSiteVisit(record.id);
      ref.invalidate(
        allSiteVisitsProvider((visitDate: null, employeeId: null, siteName: null)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site visit deleted.')),
        );
      }
    }
  }
}

class _SiteVisitMatrixView extends StatelessWidget {
  const _SiteVisitMatrixView({
    required this.focusedMonth,
    required this.visits,
    required this.onCellTap,
  });

  final DateTime focusedMonth;
  final List<SiteVisitRecord> visits;
  final void Function(String employeeName, String dateStr, List<SiteVisitRecord> dayVisits) onCellTap;

  @override
  Widget build(BuildContext context) {
    final year = focusedMonth.year;
    final month = focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isMobile = MediaQuery.of(context).size.width < 650;
    final byCell = <String, List<SiteVisitRecord>>{};
    for (final visit in visits) {
      final key = '${visit.employeeId}_${visit.visitDate}';
      byCell.putIfAbsent(key, () => []).add(visit);
    }

    final employees = visits.map((v) => MapEntry(v.employeeId, v.employeeName)).toSet().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (employees.isEmpty) {
      return _shell(
        const Center(
          child: Text('No site visits found matching filters.'),
        ),
      );
    }

    const leftColWidth = 145.0;
    const dayColWidth = 36.0;
    const rowHeight = 44.0;
    const headerHeight = 40.0;

    return _shell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.grid_on, size: 18, color: Color(0xFF9CC70A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Monthly Matrix (${DateFormat('MMM yyyy').format(focusedMonth)})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _LegendPill('Present', Color(0xFF2E7D32)),
                          _LegendPill('Late', Color(0xFFE65100)),
                          _LegendPill('Checked out', Color(0xFF414A51)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.grid_on, size: 18, color: Color(0xFF9CC70A)),
                      const SizedBox(width: 8),
                      Text(
                        'Monthly Site Visit Matrix (${DateFormat('MMMM yyyy').format(focusedMonth)})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      const _LegendPill('Present', Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      const _LegendPill('Late', Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      const _LegendPill('Checked out', Color(0xFF414A51)),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: leftColWidth,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0xFFF8F9FA),
                      alignment: Alignment.centerLeft,
                      child: const Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    for (final emp in employees) ...[
                      Container(
                        height: rowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                              child: Text(
                                emp.value.isNotEmpty ? emp.value[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(emp.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: daysInMonth * dayColWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: headerHeight,
                          color: const Color(0xFFF8F9FA),
                          child: Row(
                            children: [
                              for (int day = 1; day <= daysInMonth; day++)
                                SizedBox(
                                  width: dayColWidth,
                                  child: Center(
                                    child: Text('$day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        for (final emp in employees) ...[
                          SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                for (int day = 1; day <= daysInMonth; day++)
                                  SizedBox(
                                    width: dayColWidth,
                                    child: Center(
                                      child: _buildCell(emp.key, emp.value, day, month, year, byCell, onCellTap),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shell(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCell(
    int employeeId,
    String employeeName,
    int day,
    int month,
    int year,
    Map<String, List<SiteVisitRecord>> byCell,
    void Function(String employeeName, String dateStr, List<SiteVisitRecord> dayVisits) onCellTap,
  ) {
    final dateStr = '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-$year';
    final visits = byCell['${employeeId}_$dateStr'] ?? const [];
    final count = visits.length;
    final color = count == 0 ? Colors.grey.shade300 : const Color(0xFF9CC70A);

    return Tooltip(
      message: '$employeeName\n$dateStr\nVisits: $count',
      child: InkWell(
        onTap: count == 0 ? null : () => onCellTap(employeeName, dateStr, visits),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: count > 0 ? 0.9 : 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            count == 0 ? '-' : '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: count > 0 ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DetailedSiteVisitLogTable extends StatelessWidget {
  const _DetailedSiteVisitLogTable({
    required this.groupedVisits,
    required this.onDelete,
    required this.onLocationTap,
    required this.onPhotoTap,
  });

  final Map<String, List<SiteVisitRecord>> groupedVisits;
  final Future<void> Function(SiteVisitRecord record) onDelete;
  final Future<void> Function(SiteVisitRecord record) onLocationTap;
  final Future<void> Function(String photoUrl) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    if (groupedVisits.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: const Text('No site visits found matching filters.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Detailed log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ),
        ...groupedVisits.entries.map((entry) {
          final first = entry.value.first;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DetailedVisitDayCard(
              employeeName: first.employeeName,
              dateStr: first.visitDate,
              visits: entry.value,
              onDelete: onDelete,
              onLocationTap: onLocationTap,
              onPhotoTap: onPhotoTap,
            ),
          );
        }),
      ],
    );
  }
}

class _DetailedVisitDayCard extends StatelessWidget {
  const _DetailedVisitDayCard({
    required this.employeeName,
    required this.dateStr,
    required this.visits,
    required this.onDelete,
    required this.onLocationTap,
    required this.onPhotoTap,
  });

  final String employeeName;
  final String dateStr;
  final List<SiteVisitRecord> visits;
  final Future<void> Function(SiteVisitRecord record) onDelete;
  final Future<void> Function(SiteVisitRecord record) onLocationTap;
  final Future<void> Function(String photoUrl) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final first = visits.first;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  child: Text(
                    employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'E',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9CC70A)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employeeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _StatusChip(status: _statusForVisits(visits)),
              ],
            ),
            const SizedBox(height: 12),
            ...visits.map(
              (visit) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DetailedVisitTile(
                  visit: visit,
                  onLocationTap: onLocationTap,
                  onPhotoTap: onPhotoTap,
                ),
              ),
            ),
            if (visits.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onDelete(first),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC62828)),
                  label: const Text('Delete day entry', style: TextStyle(color: Color(0xFFC62828))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _statusForVisits(List<SiteVisitRecord> visits) {
    final latest = visits.first.visitTime;
    DateTime? parsed;
    for (final format in [DateFormat('HH:mm'), DateFormat('hh:mm a')]) {
      try {
        parsed = format.parse(latest);
        break;
      } catch (_) {}
    }
    if (parsed == null) return 'Present';
    if (parsed.hour >= 17) return 'Checked out';
    if (parsed.hour >= 10) return 'Late';
    return 'Present';
  }
}

class _DetailedVisitTile extends StatelessWidget {
  const _DetailedVisitTile({
    required this.visit,
    required this.onLocationTap,
    required this.onPhotoTap,
  });

  final SiteVisitRecord visit;
  final Future<void> Function(SiteVisitRecord record) onLocationTap;
  final Future<void> Function(String photoUrl) onPhotoTap;

  String _statusForVisit(SiteVisitRecord visit) {
    final time = visit.visitTime.trim();
    if (time.isEmpty) return 'Present';
    DateTime? parsed;
    for (final format in [DateFormat('HH:mm'), DateFormat('hh:mm a'), DateFormat('hh:mm:ss a')]) {
      try {
        parsed = format.parse(time);
        break;
      } catch (_) {}
    }
    if (parsed == null) return 'Present';
    if (parsed.hour >= 17) return 'Checked out';
    if (parsed.hour >= 10) return 'Late';
    return 'Present';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusForVisit(visit);
    final color = switch (status) {
      'Late' => const Color(0xFFE65100),
      'Checked out' => const Color(0xFF414A51),
      _ => const Color(0xFF2E7D32),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: visit.photoUrl.isEmpty ? null : () => onPhotoTap(visit.photoUrl),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: visit.photoUrl.isEmpty
                  ? const Icon(Icons.image_outlined, color: AppColors.textSecondary)
                  : Image.network(visit.photoUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        visit.siteName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _StatusChip(status: status, color: color),
                  ],
                ),
                if (visit.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(visit.notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Check-in: ${visit.visitTime}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => onLocationTap(visit),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.place_outlined, size: 14, color: Color(0xFF414A51)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          visit.address.isNotEmpty ? visit.address : '${visit.latitude}, ${visit.longitude}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF414A51)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.color});

  final String status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ??
        switch (status) {
          'Late' => const Color(0xFFE65100),
          'Checked out' => const Color(0xFF414A51),
          _ => const Color(0xFF2E7D32),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
