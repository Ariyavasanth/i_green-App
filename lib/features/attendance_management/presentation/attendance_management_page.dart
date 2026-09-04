import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../attendance/domain/attendance_status_helper.dart';
import '../../attendance/presentation/widgets/attendance_details_dialog.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../../attendance_settings/presentation/widgets/attendance_settings_embedded_view.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../on_duty/presentation/assign_on_duty_dialog.dart';
import '../../on_duty/presentation/employee_on_duty_card.dart';
import '../../on_duty/providers/on_duty_providers.dart';
import '../../site_visit_attendance/domain/site_visit_record.dart';
import '../../site_visit_attendance_management/presentation/widgets/admin_manual_site_visit_dialog.dart';
import '../../site_visit_attendance_management/providers/site_visit_attendance_management_providers.dart';
import '../../task_management/presentation/task_board_page.dart';
import '../../time_clocking/presentation/clocking_timeline_view.dart';
import '../domain/attendance_management_stats.dart';
import '../providers/attendance_management_providers.dart';
import 'widgets/admin_manual_attendance_dialog.dart';
import 'widgets/attendance_correction_dialog.dart';
import 'widgets/attendance_audit_logs_embedded_view.dart';
import 'widgets/attendance_matrix_view.dart';
import 'widgets/attendance_table_view.dart';

enum AttendanceCategoryTab {
  staticAttendance,
  siteVisitAttendance,
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
  int _currentPage = 1;
  int _rowsPerPage = 10;

  List<Employee> _getPaginatedEmployees(List<Employee> filteredList) {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    if (startIndex >= filteredList.length) return [];
    final endIndex = (startIndex + _rowsPerPage).clamp(0, filteredList.length);
    return filteredList.sublist(startIndex, endIndex);
  }

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

  void _openAttendanceCorrectionDialog(
    Employee emp,
    DateTime date,
    AttendanceRecord? record,
    AttendanceStatusInfo? statusInfo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AttendanceCorrectionDialog(
        employee: emp,
        date: date,
        record: record,
        statusInfo: statusInfo,
        onSubmitted: ({
          required String correctedCheckIn,
          required String correctedCheckOut,
          required String correctedStatus,
          required String reason,
        }) async {
          final dateStr = DateFormat('dd-MM-yyyy').format(date);
          final repo = ref.read(attendanceManagementRepositoryProvider);
          final updatedRecord = AttendanceRecord(
            id: record?.id ?? 0,
            employeeId: emp.id,
            employeeCode: emp.employeeId,
            employeeName: emp.name,
            date: dateStr,
            time: correctedCheckIn,
            status: correctedStatus,
            verificationStatus: 'Admin Correction (Firestore)',
            similarityScore: 1.0,
            checkInTime: correctedCheckIn,
            checkOutTime: correctedCheckOut,
            checkInVerificationStatus: 'Admin Correction (Firestore)',
            checkOutVerificationStatus: correctedCheckOut.isNotEmpty ? 'Admin Correction (Firestore)' : '',
            checkInSimilarityScore: 1.0,
            checkOutSimilarityScore: correctedCheckOut.isNotEmpty ? 1.0 : 0.0,
            totalHours: 0.0,
            notes: reason,
            markedAt: record?.markedAt ?? DateTime.now().toIso8601String(),
          );

          try {
            await repo.saveOrOverrideAttendance(updatedRecord);
            ref.invalidate(attendanceManagementRecordsProvider);
            ref.invalidate(attendanceManagementStatsProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Attendance updated for ${emp.name} on $dateStr!'),
                  backgroundColor: const Color(0xFF414A51),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating attendance: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
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

  void _openAssignOnDutyDialog([Employee? employee]) {
    showDialog(
      context: context,
      builder: (ctx) => AssignOnDutyDialog(
        preSelectedEmployee: employee,
      ),
    );
  }

  void _openAttendanceSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          height: 650,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Attendance Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const Expanded(child: AttendanceSettingsEmbeddedView()),
            ],
          ),
        ),
      ),
    );
  }

  void _openAuditLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;
        final dialogWidth = (screenSize.width * 0.95).clamp(300.0, 900.0);
        final dialogHeight = (screenSize.height * 0.85).clamp(400.0, 700.0);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audit Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const Expanded(child: AttendanceAuditLogsEmbeddedView()),
              ],
            ),
          ),
        );
      },
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

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF9CC70A),
              onRefresh: () async {
                ref.invalidate(allAttendanceRecordsProvider);
                ref.invalidate(employeesProvider);
                ref.invalidate(allEmployeesProvider);
                ref.invalidate(attendanceManagementStatsProvider);
                ref.invalidate(attendanceManagementRecordsProvider);
                ref.invalidate(attendanceManagementAuditProvider);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Green Header Quick Action Banner Card
                    _buildGreenQuickActionBanner(),
                    const SizedBox(height: 12),

                    // Category Tab Switcher ("Office / Site" | "Site Visits")
                    _buildCategoryTabBar(),
                    const SizedBox(height: 16),

                    if (_activeTab == AttendanceCategoryTab.staticAttendance) ...[
                      // Controls Toolbar (Month Selector, Search Box, Status Filter Chips)
                      _buildSearchAndFilterControls(employeesAsync, isMobile),
                      const SizedBox(height: 16),

                      // Section Title: Monthly Attendance Matrix + View Table ->
                      _buildSectionHeader(),
                      const SizedBox(height: 12),
                    ],

                    // Active Tab Content
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
            ),
          ),
          // Bottom Summary Bar
          if (_activeTab == AttendanceCategoryTab.staticAttendance)
            staticStatsAsync.when(
              data: (stats) => _buildBottomSummaryBar(stats),
              loading: () => _buildBottomSummaryBar(const AttendanceManagementStats(
                totalEmployees: 0,
                presentToday: 0,
                lateToday: 0,
                checkedOutToday: 0,
                absentToday: 0,
                onLeaveToday: 0,
                averageWorkHours: 0.0,
              )),
              error: (_, __) => const SizedBox.shrink(),
            )
          else if (_activeTab == AttendanceCategoryTab.siteVisitAttendance)
            siteVisitsAsync.when(
              data: (visits) => _buildSiteVisitBottomSummaryBar(visits),
              loading: () => _buildSiteVisitBottomSummaryBar([]),
              error: (_, __) => const SizedBox.shrink(),
            )
          else
            _buildBottomNavBar(isMobile),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF1E293B), size: 24),
                onPressed: () {
                  Scaffold.maybeOf(ctx)?.openDrawer();
                },
              ),
            ),
            const SizedBox(width: 4),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
                Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Live Sync Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, size: 13, color: Color(0xFF414A51)),
                  SizedBox(width: 4),
                  Text(
                    'Live Sync',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF414A51),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Notification Bell with Badge Count '3'
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF1E293B), size: 20),
                    onPressed: _openAuditLogsDialog,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Text(
                      '3',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreenQuickActionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF9CC70A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9CC70A).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderQuickActionItem(
            icon: Icons.how_to_reg_outlined,
            label: 'Office Entry',
            onTap: () => _openAdminStaticEntryDialog(),
          ),
          _buildHeaderQuickActionItem(
            icon: Icons.domain_outlined,
            label: 'Site Entry',
            onTap: () => _openAdminSiteEntryDialog(),
          ),
          _buildHeaderQuickActionItem(
            icon: Icons.badge_outlined,
            label: 'On-Duty',
            onTap: () => _openAssignOnDutyDialog(),
          ),
          _buildHeaderQuickActionItem(
            icon: Icons.access_time_rounded,
            label: 'Reports',
            onTap: () => _openAuditLogsDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CC70A)),
            ),
            const SizedBox(width: 8),
            const Text(
              'Monthly Attendance Matrix',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            setState(() {
              _viewMode = _viewMode == AttendanceViewMode.matrix
                  ? AttendanceViewMode.table
                  : AttendanceViewMode.matrix;
            });
          },
          child: Row(
            children: [
              Text(
                _viewMode == AttendanceViewMode.matrix ? 'View Table' : 'View Matrix',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF475569)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildCategoryTabBar() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCategoryTabItem(
            tab: AttendanceCategoryTab.staticAttendance,
            icon: Icons.storefront_outlined,
            label: 'Office / Site',
          ),
          _buildCategoryTabItem(
            tab: AttendanceCategoryTab.siteVisitAttendance,
            icon: Icons.location_on_outlined,
            label: 'Site Visits',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabItem({
    required AttendanceCategoryTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == tab;
    const primaryColor = Color(0xFF9CC70A);

    return Expanded(
      child: InkWell(
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
            _currentPage = 1;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? primaryColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? primaryColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(bool isMobile) {
    return _buildCategoryTabBar();
  }

  Widget _buildBottomNavItem({
    required AttendanceCategoryTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == tab;
    const primaryColor = Color(0xFF9CC70A);

    return SizedBox(
      width: 110,
      child: InkWell(
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
            _currentPage = 1;
          });
        },
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primaryColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? primaryColor : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? primaryColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
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

      case AttendanceCategoryTab.attendanceSettings:
        return const AttendanceSettingsEmbeddedView();

      case AttendanceCategoryTab.auditLogs:
        return const AttendanceAuditLogsEmbeddedView();
    }
  }

  Widget _buildActiveOnDutyBanner() {
    if (_selectedEmployeeId == null) return const SizedBox.shrink();
    final activeOnDutyAsync = ref.watch(activeOnDutyAssignmentProvider(_selectedEmployeeId!));
    return activeOnDutyAsync.when(
      data: (assignment) {
        if (assignment == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EmployeeOnDutyCard(assignment: assignment),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
        // Active On-Duty Employee Mobile Banner (If assigned)
        _buildActiveOnDutyBanner(),

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
                final filteredEmp = _filterEmployees(employees);
                final paginatedEmp = _getPaginatedEmployees(filteredEmp);

                final allLeaves = ref.watch(allLeaveRequestsProvider).valueOrNull;
                final allOnDuty = ref.watch(allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null))).valueOrNull;

                if (_viewMode == AttendanceViewMode.matrix) {
                  return Column(
                    children: [
                      AttendanceMatrixView(
                        focusedMonth: _focusedMonth,
                        employees: paginatedEmp,
                        records: filteredRecords,
                        leaves: allLeaves,
                        onDutyAssignments: allOnDuty,
                        onCellTap: (emp, date, record, statusInfo) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AttendanceDetailsDialog(
                              employee: emp,
                              date: date,
                              record: record,
                              statusInfo: statusInfo,
                              onEdit: () {
                                _openAttendanceCorrectionDialog(emp, date, record, statusInfo);
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildPaginationBar(filteredEmp.length, isMobile),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      AttendanceTableView(
                        records: filteredRecords,
                        onEdit: (record) => _openAdminStaticEntryDialog(record, record.employeeId, record.date),
                        onDelete: (record) => _handleDeleteStaticRecord(record),
                      ),
                      const SizedBox(height: 12),
                      _buildPaginationBar(filteredEmp.length, isMobile),
                    ],
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaginationBar(int totalItems, bool isMobile) {
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 9999);
    final startItem = totalItems == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1;
    final endItem = (_currentPage * _rowsPerPage).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                Text(
                  'Showing $startItem–$endItem of $totalItems employees',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text(
                      'Page $_currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Showing $startItem–$endItem of $totalItems employees',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: [10, 20, 50, 100].map((count) {
                        return DropdownMenuItem<int>(
                          value: count,
                          child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _rowsPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Previous', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Page $_currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: const Text('Next', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
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
            _buildSiteVisitControlToolbar(visits, allEmployees, isMobile),
            const SizedBox(height: 16),
            _buildSiteVisitSectionHeader(),
            const SizedBox(height: 12),
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
    final total = stats.totalEmployees;
    final presentPct = total > 0 ? (stats.presentToday * 100 / total).toStringAsFixed(0) : '0';
    final latePct = total > 0 ? (stats.lateToday * 100 / total).toStringAsFixed(0) : '0';
    final leavePct = total > 0 ? (stats.onLeaveToday * 100 / total).toStringAsFixed(0) : '0';
    final absentPct = total > 0 ? (stats.absentToday * 100 / total).toStringAsFixed(0) : '0';

    final items = [
      _KpiData(
        label: 'Total Staff',
        value: stats.totalEmployees.toString(),
        subtext: '5% vs last month',
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        icon: Icons.people_outline,
        isGrowth: true,
      ),
      _KpiData(
        label: 'Present Today',
        value: stats.presentToday.toString(),
        subtext: '$presentPct% of total staff',
        iconColor: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
        icon: Icons.check_circle_outline,
      ),
      _KpiData(
        label: 'Late Today',
        value: stats.lateToday.toString(),
        subtext: '$latePct% of total staff',
        iconColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
        icon: Icons.access_time,
      ),
      _KpiData(
        label: 'On Leave Today',
        value: stats.onLeaveToday.toString(),
        subtext: '$leavePct% of total staff',
        iconColor: const Color(0xFFCA8A04),
        bgColor: const Color(0xFFFEFCE8),
        icon: Icons.work_off_outlined,
      ),
      _KpiData(
        label: 'Absent Today',
        value: stats.absentToday.toString(),
        subtext: '$absentPct% of total staff',
        iconColor: const Color(0xFFDC2626),
        bgColor: const Color(0xFFFEF2F2),
        icon: Icons.cancel_outlined,
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.25,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFF16A34A),
              value: '$totalVisits',
              title: 'Total Visits',
              subtitle: 'Selected Month',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF2563EB),
              value: '$uniqueEmployees',
              title: 'Active Staff',
              subtitle: 'Visited Sites',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.business_outlined,
              iconColor: const Color(0xFF0D9488),
              value: '$uniqueSites',
              title: 'Unique Sites',
              subtitle: 'Locations',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.today_outlined,
              iconColor: const Color(0xFF4F46E5),
              value: '$checkedInToday',
              title: 'Visits Today',
              subtitle: 'Today\'s Logs',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteVisitBottomSummaryBar(List<SiteVisitRecord> allVisits) {
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final todayVisits = allVisits.where((v) => v.visitDate == todayStr).toList();

    final totalVisitsToday = todayVisits.length;
    final activeStaffToday = todayVisits.map((v) => v.employeeId).toSet().length;
    final uniqueSitesToday = todayVisits.map((v) => v.siteName.toLowerCase().trim()).where((s) => s.isNotEmpty).toSet().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFF16A34A),
              value: '$totalVisitsToday',
              title: 'Total Visits',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF2563EB),
              value: '$activeStaffToday',
              title: 'Active Staff',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.business_outlined,
              iconColor: const Color(0xFF0D9488),
              value: '$uniqueSitesToday',
              title: 'Unique Sites',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.today_outlined,
              iconColor: const Color(0xFF4F46E5),
              value: '$totalVisitsToday',
              title: 'Visits Today',
              subtitle: 'Today\'s Logs',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(_KpiData kpi) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kpi.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      kpi.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (kpi.isGrowth)
                const Icon(Icons.north_east, size: 10, color: Color(0xFF16A34A)),
              if (kpi.isGrowth) const SizedBox(width: 2),
              Expanded(
                child: Text(
                  kpi.subtext,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: kpi.isGrowth ? FontWeight.bold : FontWeight.w500,
                    color: kpi.isGrowth ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterControls(AsyncValue<List<Employee>> employeesAsync, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector & Filter Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Month Selector button
              InkWell(
                onTap: () => _openMonthYearPicker(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM yyyy').format(_focusedMonth),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              // Filter tune button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569), size: 20),
                onPressed: () => _openFilterBottomSheet(context, employeesAsync),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search input field
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search employee...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF9CC70A)),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          // Status Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusFilterChip('P', 'Present', const Color(0xFFE6F4EA), const Color(0xFF1E88E5)),
                _buildStatusFilterChip('A', 'Late', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                _buildStatusFilterChip('A', 'Absent', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
                _buildStatusFilterChip('OL', 'On Leave', const Color(0xFFFEF9C3), const Color(0xFF854D0E)),
                _buildStatusFilterChip('OD', 'On Duty', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                _buildStatusFilterChip('MC', 'Missing', const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
                _buildStatusFilterChip('IH', 'Ins. Hours', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
                _buildStatusFilterChip('WO', 'Weekly Off', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                _buildStatusFilterChip('H', 'Holiday', const Color(0xFFFCE7F3), const Color(0xFFBE185D)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String code, String label, Color bgColor, Color textColor) {
    final isSelected = _selectedStatus == label || _selectedStatus == code;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedStatus = 'All';
            } else {
              _selectedStatus = label;
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? textColor : textColor.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: textColor.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSummaryBar(AttendanceManagementStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.check_circle_outline,
              iconColor: const Color(0xFF16A34A),
              value: '${stats.presentToday}',
              title: 'Present',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.access_time,
              iconColor: const Color(0xFFEA580C),
              value: '${stats.lateToday}',
              title: 'Late',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.person_outline,
              iconColor: const Color(0xFFDC2626),
              value: '${stats.absentToday}',
              title: 'Absent',
              subtitle: 'Today',
            ),
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildSummaryStatItem(
              icon: Icons.work_outline,
              iconColor: const Color(0xFFCA8A04),
              value: '${stats.onLeaveToday}',
              title: 'On Leave',
              subtitle: 'Today',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            height: 1.1,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  void _openFilterBottomSheet(BuildContext context, AsyncValue<List<Employee>> employeesAsync) {
    final employees = employeesAsync.valueOrNull ?? [];
    final departmentList = ['All Departments', ...Employee.departmentOptions];
    final designationList = ['All Designations', ...Employee.designationOptions];
    final statusList = ['All', 'Present', 'Late', 'Half Day', 'Absent', 'On Duty'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDepartment = 'All Departments';
                            _selectedDesignation = 'All Designations';
                            _selectedStatus = 'All';
                            _selectedEmployeeId = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  SearchableFilterDropdown<String>(
                    width: double.infinity,
                    label: 'Department',
                    value: _selectedDepartment == 'All Departments' ? null : _selectedDepartment,
                    items: departmentList,
                    itemLabel: (item) => item,
                    searchHint: 'Search department...',
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartment = val ?? 'All Departments';
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchableFilterDropdown<String>(
                    width: double.infinity,
                    label: 'Designation',
                    value: _selectedDesignation == 'All Designations' ? null : _selectedDesignation,
                    items: designationList,
                    itemLabel: (item) => item,
                    searchHint: 'Search designation...',
                    onChanged: (val) {
                      setState(() {
                        _selectedDesignation = val ?? 'All Designations';
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchableFilterDropdown<String>(
                    width: double.infinity,
                    label: 'Status',
                    value: _selectedStatus == 'All' ? null : _selectedStatus,
                    items: statusList,
                    itemLabel: (item) => item == 'All' ? 'All Statuses' : item,
                    searchHint: 'Search status...',
                    onChanged: (val) {
                      setState(() {
                        _selectedStatus = val ?? 'All';
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _openMonthYearPicker(BuildContext context) {
    int tempYear = _focusedMonth.year;
    int tempMonth = _focusedMonth.month;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Month & Year',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Year Selector Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF475569)),
                          onPressed: () {
                            setDialogState(() {
                              tempYear--;
                            });
                          },
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                          onPressed: () {
                            setDialogState(() {
                              tempYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 12 Months Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthNum = index + 1;
                        final isSelected = monthNum == tempMonth;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _focusedMonth = DateTime(tempYear, monthNum, 1);
                            });
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              months[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildSiteVisitControlToolbar(
    List<SiteVisitRecord> visits,
    List<Employee> employees,
    bool isMobile,
  ) {
    final siteNames = visits.map((v) => v.siteName.trim()).where((s) => s.isNotEmpty).toSet().toList();
    siteNames.sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector & View Mode Switcher Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Month Selector button with Previous / Next Arrows
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF64748B)),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                        });
                      },
                    ),
                    InkWell(
                      onTap: () => _openMonthYearPicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          DateFormat('MMMM yyyy').format(_focusedMonth),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Filter Tune Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF475569), size: 20),
                onPressed: () => _openSiteVisitFilterBottomSheet(context, visits, employees),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Box
          _buildSiteSearchField(),
        ],
      ),
    );
  }

  void _openSiteVisitFilterBottomSheet(
    BuildContext context,
    List<SiteVisitRecord> visits,
    List<Employee> employees,
  ) {
    final departmentList = ['All Departments', ...Employee.departmentOptions];
    final designationList = ['All Designations', ...Employee.designationOptions];
    final siteNames = ['All', ...visits.map((v) => v.siteName.trim()).where((s) => s.isNotEmpty).toSet().toList()..sort()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Site Visits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDepartment = 'All Departments';
                            _selectedDesignation = 'All Designations';
                            _selectedSite = 'All';
                            _selectedEmployeeId = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  SearchableFilterDropdown<String>(
                    width: double.infinity,
                    label: 'Department',
                    value: _selectedDepartment == 'All Departments' ? null : _selectedDepartment,
                    items: departmentList,
                    itemLabel: (item) => item,
                    searchHint: 'Search department...',
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartment = val ?? 'All Departments';
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchableFilterDropdown<String>(
                    width: double.infinity,
                    label: 'Designation',
                    value: _selectedDesignation == 'All Designations' ? null : _selectedDesignation,
                    items: designationList,
                    itemLabel: (item) => item,
                    searchHint: 'Search designation...',
                    onChanged: (val) {
                      setState(() {
                        _selectedDesignation = val ?? 'All Designations';
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildSiteSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search site logs...',
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9CC70A)),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
    );
  }

  Widget _buildSiteFilterDropdown(List<String> siteNames) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSite,
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.business_outlined, size: 18, color: Color(0xFF9CC70A)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9CC70A)),
        ),
      ),
      items: [
        const DropdownMenuItem(value: 'All', child: Text('All Sites', overflow: TextOverflow.ellipsis)),
        ...siteNames.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedSite = val);
      },
    );
  }

  Widget _buildSiteVisitSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _viewMode == AttendanceViewMode.matrix ? Icons.grid_on : Icons.table_rows,
                size: 16,
                color: const Color(0xFF9CC70A),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _viewMode == AttendanceViewMode.matrix ? 'Site Visit Matrix' : 'Site Visit Logs',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            setState(() {
              _viewMode = _viewMode == AttendanceViewMode.matrix
                  ? AttendanceViewMode.table
                  : AttendanceViewMode.matrix;
            });
          },
          child: Row(
            children: [
              Text(
                _viewMode == AttendanceViewMode.matrix ? 'View Log Table' : 'View Matrix',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF475569)),
            ],
          ),
        ),
      ],
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
    final empMap = {for (final e in employees) e.id: e};

    return visits.where((v) {
      final emp = empMap[v.employeeId];
      if (_selectedEmployeeId != null && v.employeeId != _selectedEmployeeId) return false;
      if (_selectedDepartment != 'All Departments' && emp?.department != _selectedDepartment) return false;
      if (_selectedDesignation != 'All Designations' && emp?.designation != _selectedDesignation) return false;
      if (_selectedSite != 'All' && v.siteName.toLowerCase().trim() != _selectedSite.toLowerCase().trim()) return false;
      
      // Month & Year Filter
      try {
        final parts = v.visitDate.split('-');
        if (parts.length == 3) {
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (month != null && year != null) {
            if (month != _focusedMonth.month || year != _focusedMonth.year) return false;
          }
        }
      } catch (_) {}

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

  void _openSiteVisitDetailsDialog(SiteVisitRecord v) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: Color(0xFF9CC70A), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Site Visit Details',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (v.photoUrl.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _openFullImagePreview(v.photoUrl, v.siteName),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildSiteVisitImageWidget(v.photoUrl, width: double.infinity, height: 180),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to view full image',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRowItem(Icons.person_outline, 'Employee', v.employeeName),
                _buildDetailRowItem(Icons.business_outlined, 'Site Name', v.siteName),
                _buildDetailRowItem(Icons.calendar_today_outlined, 'Date & Time', '${v.visitDate}  ${v.visitTime}'),
                _buildDetailRowItem(Icons.map_outlined, 'Location / Address', v.address.isNotEmpty ? v.address : 'N/A'),
                _buildDetailRowItem(
                  Icons.my_location,
                  'GPS Coordinates',
                  '${v.latitude.toStringAsFixed(6)}, ${v.longitude.toStringAsFixed(6)}',
                ),
                if (v.notes.isNotEmpty)
                  _buildDetailRowItem(Icons.notes_outlined, 'Purpose / Notes', v.notes),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRowItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              const DataColumn(
                label: SizedBox(
                  width: 140,
                  child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              for (int day = 1; day <= daysInMonth; day++)
                DataColumn(
                  label: SizedBox(
                    width: 68,
                    child: Center(
                      child: Text(
                        '$day',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
            rows: grouped.entries.map((entry) {
              final empName = entry.key;
              final dateMap = entry.value;

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 140,
                      child: Text(
                        empName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  for (int day = 1; day <= daysInMonth; day++) ...[
                    (() {
                      final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                      final dateStr = DateFormat('dd-MM-yyyy').format(dayDate);
                      final dayVisits = dateMap[dateStr] ?? [];

                      if (dayVisits.isEmpty) {
                        return const DataCell(
                          SizedBox(
                            width: 68,
                            child: Center(child: Text('-', style: TextStyle(color: Colors.grey))),
                          ),
                        );
                      }

                      return DataCell(
                        SizedBox(
                          width: 68,
                          child: Center(
                            child: InkWell(
                              onTap: () => _openDaySiteTimelineDialog(empName, dateStr, dayVisits),
                              child: Container(
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(36),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'No site visit logs found.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                SizedBox(height: 4),
                Text(
                  'Try selecting a different month or clearing search filters.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Site Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Address / GPS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
            ],
            rows: visits.map((v) {
              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => _openSiteVisitDetailsDialog(v),
                      child: Row(
                        children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                              child: Text(
                                v.employeeName.trim().isNotEmpty
                                    ? v.employeeName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
                                    : 'E',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(v.employeeName, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openSiteVisitDetailsDialog(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FEE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Color(0xFF414A51)),
                            const SizedBox(width: 4),
                            Text(v.siteName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openSiteVisitDetailsDialog(v),
                      child: Text('${v.visitDate}\n${v.visitTime}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openSiteVisitDetailsDialog(v),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.address.isNotEmpty ? v.address : 'GPS Recorded',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${v.latitude.toStringAsFixed(4)}, ${v.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    v.photoUrl.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _openFullImagePreview(v.photoUrl, v.siteName),
                            child: _buildSiteVisitImageWidget(v.photoUrl, width: 40, height: 40),
                          )
                        : const Text('-', style: TextStyle(color: Colors.grey)),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openSiteVisitDetailsDialog(v),
                      child: Text(
                        v.notes.isEmpty ? '-' : v.notes,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                          tooltip: 'Edit Site Visit',
                          onPressed: () => _openAdminSiteEntryDialog(v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          tooltip: 'Delete Site Visit',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Site Visit'),
                                content: Text('Delete site visit record for ${v.employeeName} at ${v.siteName}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
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

  Widget _buildSiteVisitImageWidget(String photoUrl, {double width = 52, double height = 52}) {
    if (photoUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Icon(Icons.location_on, color: Color(0xFF9CC70A), size: 22),
      );
    }

    Widget imageChild;
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      imageChild = Image.network(
        photoUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
        ),
      );
    } else {
      final file = File(photoUrl);
      if (file.existsSync()) {
        imageChild = Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
            width: width,
            height: height,
            color: const Color(0xFFF1F5F9),
            child: const Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey),
          ),
        );
      } else {
        imageChild = Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Icon(Icons.image_not_supported_outlined, size: 20, color: Colors.grey),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageChild,
    );
  }

  void _openFullImagePreview(String photoUrl, String siteName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Captured Site Photo ($siteName)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildSiteVisitImageWidget(photoUrl, width: 450, height: 350),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDaySiteTimelineDialog(String employeeName, String dateStr, List<SiteVisitRecord> dayVisits) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF9CC70A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Site Visits: $employeeName ($dateStr)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: dayVisits.whereType<SiteVisitRecord>().map((v) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Image Thumbnail with Tap to View Full Screen
                      GestureDetector(
                        onTap: () {
                          if (v.photoUrl.isNotEmpty) {
                            _openFullImagePreview(v.photoUrl, v.siteName);
                          }
                        },
                        child: Stack(
                          children: [
                            _buildSiteVisitImageWidget(v.photoUrl, width: 56, height: 56),
                            if (v.photoUrl.isNotEmpty)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    v.siteName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FEE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF9CC70A).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    v.visitTime,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${v.address.isNotEmpty ? v.address : '${v.latitude}, ${v.longitude}'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            if (v.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Notes: ${v.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
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
  _KpiData({
    required this.label,
    required this.value,
    required this.subtext,
    required this.iconColor,
    required this.bgColor,
    required this.icon,
    this.isGrowth = false,
  });

  final String label;
  final String value;
  final String subtext;
  final Color iconColor;
  final Color bgColor;
  final IconData icon;
  final bool isGrowth;
}

class SearchableFilterDropdown<T> extends StatelessWidget {
  const SearchableFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.searchHint = 'Search...',
    this.width,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;
  final String searchHint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final selectedText = value != null ? itemLabel(value as T) : label;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _openSearchDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _SearchFilterDialog<T>(
        title: label,
        searchHint: searchHint,
        items: items,
        selectedValue: value,
        itemLabel: itemLabel,
        onSelected: (val) {
          onChanged(val);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _SearchFilterDialog<T> extends StatefulWidget {
  const _SearchFilterDialog({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.onSelected,
  });

  final String title;
  final String searchHint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onSelected;

  @override
  State<_SearchFilterDialog<T>> createState() => _SearchFilterDialogState<T>();
}

class _SearchFilterDialogState<T> extends State<_SearchFilterDialog<T>> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((item) {
      final label = widget.itemLabel(item).toLowerCase();
      return label.contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 360,
        height: 420,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching items', style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item == widget.selectedValue;
                        final label = widget.itemLabel(item);

                        return ListTile(
                          dense: true,
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFF0F172A),
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check, size: 16, color: Color(0xFF9CC70A)) : null,
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


