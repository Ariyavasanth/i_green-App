import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../attendance_settings/presentation/widgets/attendance_settings_embedded_view.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../../site_visit_attendance_management/presentation/widgets/admin_manual_site_visit_dialog.dart';
import '../../site_visit_attendance_management/presentation/widgets/assign_on_duty_dialog.dart';
import '../../site_visit_attendance_management/presentation/widgets/on_duty_management_view.dart';
import '../../site_visit_attendance_management/providers/site_visit_attendance_management_providers.dart';
import '../domain/attendance_management_stats.dart';
import '../providers/attendance_management_providers.dart';
import 'widgets/admin_manual_attendance_dialog.dart';
import 'widgets/attendance_audit_logs_embedded_view.dart';
import 'widgets/attendance_matrix_view.dart';
import 'widgets/attendance_table_view.dart';

enum AttendanceCategoryTab {
  staticAttendance,
  siteVisitAttendance,
  onDutyManagement,
  attendanceSettings,
  auditLogs,
}

enum AttendanceViewMode { matrix, table }

class AttendanceManagementPage extends ConsumerStatefulWidget {
  const AttendanceManagementPage({
    super.key,
    this.initialTab = AttendanceCategoryTab.staticAttendance,
  });

  final AttendanceCategoryTab initialTab;

  @override
  ConsumerState<AttendanceManagementPage> createState() => _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends ConsumerState<AttendanceManagementPage> {
  late AttendanceCategoryTab _activeTab;
  DateTime _focusedMonth = DateTime.now();
  int? _selectedEmployeeId;
  String _selectedDepartment = 'All Departments';
  String _selectedDesignation = 'All Designations';
  String _selectedStatus = 'All';
  String _selectedSite = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AttendanceViewMode _viewMode = AttendanceViewMode.matrix;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAdminStaticEntryDialog([AttendanceRecord? record, int? empId, String? dateStr]) {
    showDialog(
      context: context,
      builder: (ctx) => AdminManualAttendanceDialog(
        existingRecord: record,
        initialEmployeeId: empId,
        initialDate: dateStr,
        onSaved: () {
          ref.invalidate(attendanceManagementRecordsProvider);
          ref.invalidate(attendanceManagementStatsProvider);
        },
      ),
    );
  }

  void _openAdminSiteEntryDialog([SiteVisitRecord? visit]) {
    showDialog(
      context: context,
      builder: (ctx) => AdminManualSiteVisitDialog(
        existingVisit: visit,
        onSaved: () {
          ref.invalidate(allSiteVisitsProvider);
        },
      ),
    );
  }

  void _openAssignOnDutyDialog([Employee? employee, SiteVisitRecord? visit]) {
    showDialog(
      context: context,
      builder: (ctx) => AssignOnDutyDialog(
        initialEmployee: employee,
        initialVisit: visit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final monthYearStr = DateFormat('MM-yyyy').format(_focusedMonth);
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final employeesAsync = ref.watch(employeesProvider);
    final staticStatsAsync = _activeTab == AttendanceCategoryTab.staticAttendance
        ? ref.watch(attendanceManagementStatsProvider(todayStr))
        : const AsyncValue<AttendanceManagementStats>.loading();

    final staticRecordsAsync = _activeTab == AttendanceCategoryTab.staticAttendance
        ? ref.watch(attendanceManagementRecordsProvider((
            employeeId: _selectedEmployeeId,
            monthYear: monthYearStr,
            statusFilter: _selectedStatus,
          )))
        : const AsyncValue<List<AttendanceRecord>>.data([]);

    final siteVisitsAsync = _activeTab == AttendanceCategoryTab.siteVisitAttendance
        ? ref.watch(allSiteVisitsProvider((visitDate: null, employeeId: null, siteName: null)))
        : const AsyncValue<List<SiteVisitRecord>>.data([]);

    final allEmployeesList = employeesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Page Header with Quick Actions
            _buildPageHeader(context, isMobile),
            const SizedBox(height: 16),

            // Segmented Tab Selector
            _buildTabSelector(isMobile),
            const SizedBox(height: 16),

            // Tab View Body
            _buildActiveTabContent(
              isMobile: isMobile,
              allEmployees: allEmployeesList,
              staticStatsAsync: staticStatsAsync,
              staticRecordsAsync: staticRecordsAsync,
              siteVisitsAsync: siteVisitsAsync,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, bool isMobile) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final titleWidget = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.co_present, size: 26, color: primaryColor),
            SizedBox(width: 8),
            Text(
              'Attendance Management',
              style: TextStyle(
                fontSize: 20,
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
                'Live Sync',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openAdminStaticEntryDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Manual Static Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openAdminSiteEntryDialog(),
          icon: const Icon(Icons.add_location_alt_outlined, size: 16),
          label: const Text('Manual Site Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: secondaryColor,
            side: const BorderSide(color: secondaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _openAssignOnDutyDialog(),
          icon: const Icon(Icons.assignment_ind_outlined, size: 16),
          label: const Text('Assign On-Duty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        titleWidget,
        actionButtons,
      ],
    );
  }

  Widget _buildTabSelector(bool isMobile) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabButton(
                tab: AttendanceCategoryTab.staticAttendance,
                icon: Icons.home_work_outlined,
                label: 'Static Attendance',
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                tab: AttendanceCategoryTab.siteVisitAttendance,
                icon: Icons.explore_outlined,
                label: 'Site Visit Attendance',
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                tab: AttendanceCategoryTab.onDutyManagement,
                icon: Icons.assignment_ind_outlined,
                label: 'On-Duty Management',
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                tab: AttendanceCategoryTab.attendanceSettings,
                icon: Icons.tune,
                label: 'Attendance Settings',
              ),
              const SizedBox(width: 6),
              _buildTabButton(
                tab: AttendanceCategoryTab.auditLogs,
                icon: Icons.history_edu,
                label: 'Audit Logs',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required AttendanceCategoryTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == tab;
    const primaryColor = Color(0xFF9CC70A);

    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tab;
          _selectedEmployeeId = null;
          _selectedDepartment = 'All Departments';
          _selectedDesignation = 'All Designations';
          _selectedStatus = 'All';
          _selectedSite = 'All';
          _searchQuery = '';
          _searchController.clear();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF414A51)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF414A51),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent({
    required bool isMobile,
    required List<Employee> allEmployees,
    required AsyncValue<AttendanceManagementStats> staticStatsAsync,
    required AsyncValue<List<AttendanceRecord>> staticRecordsAsync,
    required AsyncValue<List<SiteVisitRecord>> siteVisitsAsync,
  }) {
    switch (_activeTab) {
      case AttendanceCategoryTab.staticAttendance:
        return _buildStaticAttendanceView(isMobile, allEmployees, staticStatsAsync, staticRecordsAsync);

      case AttendanceCategoryTab.siteVisitAttendance:
        return _buildSiteVisitAttendanceView(isMobile, allEmployees, siteVisitsAsync);

      case AttendanceCategoryTab.onDutyManagement:
        return const OnDutyManagementView();

      case AttendanceCategoryTab.attendanceSettings:
        return const AttendanceSettingsEmbeddedView();

      case AttendanceCategoryTab.auditLogs:
        return const AttendanceAuditLogsEmbeddedView();
    }
  }

  Widget _buildStaticAttendanceView(
    bool isMobile,
    List<Employee> allEmployees,
    AsyncValue<AttendanceManagementStats> statsAsync,
    AsyncValue<List<AttendanceRecord>> recordsAsync,
  ) {
    final employeesAsync = ref.watch(employeesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Banner
        statsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (stats) => _buildStaticKpiBanner(stats, isMobile),
        ),
        const SizedBox(height: 16),

        // Controls Toolbar
        _buildStaticControlToolbar(employeesAsync, isMobile),
        const SizedBox(height: 16),

        // Matrix / Table Content
        employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading employees: $e'),
          data: (employees) {
            return recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading attendance records: $e'),
              data: (records) {
                final filteredRecords = _filterStaticRecords(records, employees);

                if (_viewMode == AttendanceViewMode.matrix) {
                  return AttendanceMatrixView(
                    focusedMonth: _focusedMonth,
                    employees: _filterEmployees(employees),
                    records: filteredRecords,
                    onCellTap: (emp, dateStr, record) {
                      _openAdminStaticEntryDialog(
                        record,
                        emp.id,
                        dateStr,
                      );
                    },
                  );
                } else {
                  return AttendanceTableView(
                    records: filteredRecords,
                    onEdit: (record) => _openAdminStaticEntryDialog(record, record.employeeId, record.date),
                    onDelete: (record) => _handleDeleteStaticRecord(record),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSiteVisitAttendanceView(
    bool isMobile,
    List<Employee> allEmployees,
    AsyncValue<List<SiteVisitRecord>> visitsAsync,
  ) {
    return visitsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error loading site visits: $e'),
      data: (visits) {
        final filteredVisits = _filterSiteVisits(visits, allEmployees);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSiteVisitKpiBanner(filteredVisits, isMobile),
            const SizedBox(height: 16),
            _buildSiteVisitControlToolbar(visits, allEmployees, isMobile),
            const SizedBox(height: 16),
            if (_viewMode == AttendanceViewMode.matrix)
              _buildSiteVisitMatrixView(filteredVisits)
            else
              _buildSiteVisitTable(filteredVisits),
          ],
        );
      },
    );
  }

  // --- Static Attendance KPI & Controls ---

  Widget _buildStaticKpiBanner(AttendanceManagementStats stats, bool isMobile) {
    final items = [
      _KpiData('Total Staff', stats.totalEmployees.toString(), Colors.blue, Icons.people_alt_outlined),
      _KpiData('Present Today', stats.presentToday.toString(), Colors.green, Icons.check_circle_outline),
      _KpiData('Late Today', stats.lateToday.toString(), Colors.orange, Icons.access_time),
      _KpiData('On Leave Today', stats.onLeaveToday.toString(), Colors.amber.shade800, Icons.timelapse),
      _KpiData('Absent Today', stats.absentToday.toString(), Colors.red, Icons.cancel_outlined),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildKpiCard(items[index]),
      );
    }

    return Row(
      children: items.map((kpi) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildKpiCard(kpi)))).toList(),
    );
  }

  Widget _buildSiteVisitKpiBanner(List<SiteVisitRecord> visits, bool isMobile) {
    final totalVisits = visits.length;
    final uniqueEmployees = visits.map((v) => v.employeeId).toSet().length;
    final uniqueSites = visits.map((v) => v.siteName.toLowerCase().trim()).toSet().length;
    final checkedInToday = visits.where((v) => v.visitDate == DateFormat('dd-MM-yyyy').format(DateTime.now())).length;

    final items = [
      _KpiData('Total Visits', totalVisits.toString(), const Color(0xFF9CC70A), Icons.location_on_outlined),
      _KpiData('Active Staff', uniqueEmployees.toString(), Colors.blue, Icons.people_outline),
      _KpiData('Unique Sites', uniqueSites.toString(), Colors.teal, Icons.business_outlined),
      _KpiData('Visits Today', checkedInToday.toString(), Colors.indigo, Icons.today_outlined),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildKpiCard(items[index]),
      );
    }

    return Row(
      children: items.map((kpi) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildKpiCard(kpi)))).toList(),
    );
  }

  Widget _buildKpiCard(_KpiData kpi) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kpi.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(kpi.icon, color: kpi.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kpi.color),
                  ),
                  Text(
                    kpi.label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticControlToolbar(AsyncValue<List<Employee>> employeesAsync, bool isMobile) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Month Picker
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),

            // View Mode Segmented Button
            SegmentedButton<AttendanceViewMode>(
              segments: const [
                ButtonSegment(
                  value: AttendanceViewMode.matrix,
                  icon: Icon(Icons.grid_on, size: 16),
                  label: Text('Matrix', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: AttendanceViewMode.table,
                  icon: Icon(Icons.table_rows, size: 16),
                  label: Text('Table', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (set) => setState(() => _viewMode = set.first),
            ),

            // Employee Filter
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: employeesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (employees) => DropdownButtonFormField<int?>(
                  initialValue: _selectedEmployeeId,
                  decoration: InputDecoration(
                    labelText: 'Employee',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All Employees')),
                    ...employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                ),
              ),
            ),

            // Status Filter
            SizedBox(
              width: isMobile ? double.infinity : 160,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'Present', child: Text('Present')),
                  DropdownMenuItem(value: 'Late', child: Text('Late')),
                  DropdownMenuItem(value: 'Half Day', child: Text('Half Day')),
                  DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'On Duty', child: Text('On Duty')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
            ),

            // Search Box
            SizedBox(
              width: isMobile ? double.infinity : 200,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteVisitControlToolbar(
    List<SiteVisitRecord> visits,
    List<Employee> employees,
    bool isMobile,
  ) {
    final siteNames = visits.map((v) => v.siteName.trim()).where((s) => s.isNotEmpty).toSet().toList();
    siteNames.sort();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Month Selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),

            // View Mode
            SegmentedButton<AttendanceViewMode>(
              segments: const [
                ButtonSegment(
                  value: AttendanceViewMode.matrix,
                  icon: Icon(Icons.grid_on, size: 16),
                  label: Text('Matrix', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: AttendanceViewMode.table,
                  icon: Icon(Icons.table_rows, size: 16),
                  label: Text('Log Table', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (set) => setState(() => _viewMode = set.first),
            ),

            // Site Name Filter
            SizedBox(
              width: isMobile ? double.infinity : 200,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedSite,
                decoration: InputDecoration(
                  labelText: 'Filter Site',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Sites')),
                  ...siteNames.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSite = val);
                },
              ),
            ),

            // Search
            SizedBox(
              width: isMobile ? double.infinity : 200,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search site logs...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Filtering Helpers ---

  List<AttendanceRecord> _filterStaticRecords(List<AttendanceRecord> records, List<Employee> employees) {
    return records.where((r) {
      if (_selectedEmployeeId != null && r.employeeId != _selectedEmployeeId) return false;
      if (_selectedStatus != 'All' && r.status.toLowerCase() != _selectedStatus.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        final empName = r.employeeName.toLowerCase();
        final notes = (r.notes ?? '').toLowerCase();
        if (!empName.contains(_searchQuery) && !notes.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  List<Employee> _filterEmployees(List<Employee> employees) {
    return employees.where((e) {
      if (_selectedEmployeeId != null && e.id != _selectedEmployeeId) return false;
      if (_selectedDepartment != 'All Departments' && e.department != _selectedDepartment) return false;
      if (_selectedDesignation != 'All Designations' && e.designation != _selectedDesignation) return false;
      if (_searchQuery.isNotEmpty) {
        final name = e.name.toLowerCase();
        if (!name.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  List<SiteVisitRecord> _filterSiteVisits(List<SiteVisitRecord> visits, List<Employee> employees) {
    return visits.where((v) {
      if (_selectedEmployeeId != null && v.employeeId != _selectedEmployeeId) return false;
      if (_selectedSite != 'All' && v.siteName.toLowerCase() != _selectedSite.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        final name = v.employeeName.toLowerCase();
        final site = v.siteName.toLowerCase();
        final addr = v.address.toLowerCase();
        final notes = v.notes.toLowerCase();
        if (!name.contains(_searchQuery) &&
            !site.contains(_searchQuery) &&
            !addr.contains(_searchQuery) &&
            !notes.contains(_searchQuery)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleDeleteStaticRecord(AttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attendance Record'),
        content: Text('Are you sure you want to delete attendance record for ${record.employeeName} on ${record.date}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(attendanceManagementRepositoryProvider).deleteAttendanceRecord(record.employeeId, record.date);
      ref.invalidate(attendanceManagementRecordsProvider);
      ref.invalidate(attendanceManagementStatsProvider);
    }
  }

  // --- Site Visit Specific Sub-Views ---

  Widget _buildSiteVisitMatrixView(List<SiteVisitRecord> visits) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final grouped = <String, Map<String, List<SiteVisitRecord>>>{};

    for (final v in visits) {
      grouped.putIfAbsent(v.employeeName, () => {});
      grouped[v.employeeName]!.putIfAbsent(v.visitDate, () => []);
      grouped[v.employeeName]![v.visitDate]!.add(v);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: [
              const DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
              for (int day = 1; day <= daysInMonth; day++)
                DataColumn(
                  label: Center(
                    child: Text(
                      '$day',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
            ],
            rows: grouped.entries.map((entry) {
              final empName = entry.key;
              final dateMap = entry.value;

              return DataRow(
                cells: [
                  DataCell(Text(empName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  for (int day = 1; day <= daysInMonth; day++) ...[
                    (() {
                      final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                      final dateStr = DateFormat('dd-MM-yyyy').format(dayDate);
                      final dayVisits = dateMap[dateStr] ?? [];

                      if (dayVisits.isEmpty) {
                        return const DataCell(Center(child: Text('-', style: TextStyle(color: Colors.grey))));
                      }

                      return DataCell(
                        InkWell(
                          onTap: () => _openDaySiteTimelineDialog(empName, dateStr, dayVisits),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF9CC70A)),
                            ),
                            child: Text(
                              '${dayVisits.length} site(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF414A51),
                              ),
                            ),
                          ),
                        ),
                      );
                    })(),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSiteVisitTable(List<SiteVisitRecord> visits) {
    if (visits.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No site visit logs found.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            columns: const [
              DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Site Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Address / Geo Coordinates', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: visits.map((v) {
              return DataRow(
                cells: [
                  DataCell(Text(v.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFF9CC70A)),
                        const SizedBox(width: 4),
                        Text(v.siteName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DataCell(Text('${v.visitDate} ${v.visitTime}')),
                  DataCell(
                    InkWell(
                      onTap: () {
                        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${v.latitude},${v.longitude}');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: Text(
                        v.address.isNotEmpty ? v.address : '${v.latitude.toStringAsFixed(4)}, ${v.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  DataCell(Text(v.notes.isEmpty ? '-' : v.notes)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF414A51)),
                          onPressed: () => _openAdminSiteEntryDialog(v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Site Visit'),
                                content: Text('Delete site visit record for ${v.employeeName} at ${v.siteName}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref.read(siteVisitAttendanceManagementRepositoryProvider).deleteSiteVisit(v.id);
                              ref.invalidate(allSiteVisitsProvider);
                            }
                          },
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

  void _openDaySiteTimelineDialog(String employeeName, String dateStr, List<SiteVisitRecord> dayVisits) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Site Visits: $employeeName ($dateStr)'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: dayVisits.map((v) {
              return ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFF9CC70A)),
                title: Text(v.siteName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Time: ${v.visitTime}\nLocation: ${v.address.isNotEmpty ? v.address : '${v.latitude}, ${v.longitude}'}'),
                isThreeLine: true,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _KpiData {
  _KpiData(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;
}
