import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/leave_request.dart';
import '../domain/leave_type.dart';
import '../providers/leave_providers.dart';

enum LeaveTab { dashboard, requests, calendar, permissions }

class LeaveManagementPage extends ConsumerStatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  ConsumerState<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends ConsumerState<LeaveManagementPage> {
  LeaveTab _activeTab = LeaveTab.dashboard;
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedCalendarDate = DateTime.now();

  // Requests Tab Filters
  String _searchQuery = '';
  int? _filterEmployeeId;
  String _filterStatus = 'All Status';
  String _filterLeaveType = 'All Leave Types';
  String _filterDepartment = 'All Departments';
  String _filterDesignation = 'All Designations';

  // Helper date parsing
  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  Color _parseHexColor(String hexString) {
    try {
      String cleanHex = hexString.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  String _formatDateDisplay(String dateStr) {
    final parsed = _parseDate(dateStr);
    if (parsed == null) return dateStr;
    return DateFormat('dd-MM-yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final allRequestsAsync = ref.watch(allLeaveRequestsProvider);
    final leaveTypesAsync = ref.watch(leaveTypesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: SelectableText('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (employees) {
          final allRequests = allRequestsAsync.value ?? [];
          final leaveTypes = leaveTypesAsync.value ?? [];

          final pendingRequestsCount = allRequests.where((r) => r.status == 'Pending').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title & Apply Leave Button
                _buildTopHeader(context, employees, leaveTypes, currentEmp),
                const SizedBox(height: 20),

                // Navigation Tab Bar
                _buildNavigationBar(pendingRequestsCount),
                const SizedBox(height: 24),

                // Active Tab Body
                switch (_activeTab) {
                  LeaveTab.dashboard => _buildDashboardTab(allRequests, employees, leaveTypes),
                  LeaveTab.requests => _buildRequestsTab(allRequests, employees, leaveTypes),
                  LeaveTab.calendar => _buildCalendarTab(allRequests, employees, leaveTypes),
                  LeaveTab.permissions => _buildPermissionsTab(employees, leaveTypes),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER & APPLY LEAVE DIALOG
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(
    BuildContext context,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
    Employee? currentEmp,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.calendar_month_outlined, size: 24, color: AppColors.active),
        ),
        const SizedBox(width: 12),
        Text(
          'Leave Management',
          style: TextStyle(
            fontSize: isMobile ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D8A4E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 18,
              vertical: isMobile ? 10 : 14,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: () => _showApplyLeaveDialog(context, employees, leaveTypes, currentEmp),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            '+ Apply Leave for Employee',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showApplyLeaveDialog(
    BuildContext context,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
    Employee? currentEmp,
  ) {
    Employee? selectedEmployee = currentEmp ?? (employees.isNotEmpty ? employees.first : null);
    LeaveType? selectedLeaveType = leaveTypes.isNotEmpty ? leaveTypes.first : null;
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    final reasonController = TextEditingController();
    bool isEmergency = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final days = toDate.difference(fromDate).inDays + 1;

          return AlertDialog(
            title: const Text('Apply Leave for Employee', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Employee>(
                      value: selectedEmployee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: employees.map((e) {
                        return DropdownMenuItem<Employee>(
                          value: e,
                          child: Text('${e.fullName} (${e.employeeId}) - ${e.department}'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedEmployee = val),
                    ),
                    const SizedBox(height: 16),
                    const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<LeaveType>(
                      value: selectedLeaveType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: leaveTypes.map((t) {
                        return DropdownMenuItem<LeaveType>(
                          value: t,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _parseHexColor(t.colorHex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(t.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedLeaveType = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: fromDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      fromDate = picked;
                                      if (toDate.isBefore(fromDate)) toDate = fromDate;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd-MM-yyyy').format(fromDate)),
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    ],
                                  ),
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
                              const Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: toDate,
                                    firstDate: fromDate,
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => toDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd-MM-yyyy').format(toDate)),
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Duration: ${days > 0 ? days : 1} day(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Enter reason for leave...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Emergency Leave Request', style: TextStyle(fontSize: 13)),
                      value: isEmergency,
                      onChanged: (v) => setDialogState(() => isEmergency = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D8A4E)),
                onPressed: () async {
                  if (selectedEmployee == null || selectedLeaveType == null) return;
                  final fromStr = DateFormat('dd-MM-yyyy').format(fromDate);
                  final toStr = DateFormat('dd-MM-yyyy').format(toDate);

                  final newRequest = LeaveRequest(
                    id: 0,
                    employeeId: selectedEmployee!.id,
                    employeeName: selectedEmployee!.fullName,
                    employeeCustomId: selectedEmployee!.employeeId,
                    leaveType: selectedLeaveType!.name,
                    fromDate: fromStr,
                    toDate: toStr,
                    numDays: (days > 0 ? days : 1).toDouble(),
                    reason: reasonController.text.trim(),
                    status: 'Pending',
                    createdAt: DateTime.now().toIso8601String(),
                    approvedDates: [],
                    lopDates: [],
                    isEmergency: isEmergency,
                  );

                  await ref.read(leaveRepositoryProvider).submitLeaveRequest(newRequest);
                  ref.invalidate(allLeaveRequestsProvider);
                  ref.invalidate(leaveRequestsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. NAVIGATION BAR
  // ---------------------------------------------------------------------------
  Widget _buildNavigationBar(int pendingCount) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Row(
        children: [
          _buildTabItem(LeaveTab.dashboard, 'Dashboard'),
          _buildTabItem(LeaveTab.requests, 'Requests', badgeCount: pendingCount),
          _buildTabItem(LeaveTab.calendar, 'Calendar'),
          _buildTabItem(LeaveTab.permissions, 'Permissions & Leave Types'),
        ],
      ),
    );
  }

  Widget _buildTabItem(LeaveTab tab, String title, {int? badgeCount}) {
    final isActive = _activeTab == tab;

    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF0D8A4E) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF0D8A4E) : const Color(0xFF64748B),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. DASHBOARD TAB
  // ---------------------------------------------------------------------------
  Widget _buildDashboardTab(
    List<LeaveRequest> allRequests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    final pendingCount = allRequests.where((r) => r.status == 'Pending').length;
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final onLeaveTodayRequests = allRequests.where((r) {
      if (r.status != 'Approved') return false;
      return r.approvedDates.contains(todayStr);
    }).toList();

    final approvedThisMonthCount = allRequests.where((r) {
      if (r.status != 'Approved') return false;
      final dt = _parseDate(r.fromDate);
      return dt != null && dt.month == DateTime.now().month && dt.year == DateTime.now().year;
    }).length;

    final recentRequests = List<LeaveRequest>.from(allRequests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Summary Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth = (constraints.maxWidth - (12 * 3)) / 4;
            final isNarrow = constraints.maxWidth < 1000;

            if (isNarrow) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildKpiCard('Pending Requests', '$pendingCount', Icons.hourglass_empty, const Color(0xFFFEF3C7), const Color(0xFFD97706), 180),
                  _buildKpiCard('On Leave Today', '${onLeaveTodayRequests.length}', Icons.brightness_1, const Color(0xFFD1FAE5), const Color(0xFF059669), 180),
                  _buildKpiCard('Approved This Month', '$approvedThisMonthCount', Icons.calendar_today, const Color(0xFFDBEAFE), const Color(0xFF2563EB), 180),
                  _buildKpiCard('Total Employees', '${employees.length}', Icons.people, const Color(0xFFF3E8FF), const Color(0xFF9333EA), 180),
                ],
              );
            }

            return Row(
              children: [
                _buildKpiCard('Pending Requests', '$pendingCount', Icons.hourglass_empty, const Color(0xFFFEF3C7), const Color(0xFFD97706), cardWidth),
                const SizedBox(width: 12),
                _buildKpiCard('On Leave Today', '${onLeaveTodayRequests.length}', Icons.brightness_1, const Color(0xFFD1FAE5), const Color(0xFF059669), cardWidth),
                const SizedBox(width: 12),
                _buildKpiCard('Approved This Month', '$approvedThisMonthCount', Icons.calendar_today, const Color(0xFFDBEAFE), const Color(0xFF2563EB), cardWidth),
                const SizedBox(width: 12),
                _buildKpiCard('Total Employees', '${employees.length}', Icons.people, const Color(0xFFF3E8FF), const Color(0xFF9333EA), cardWidth),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Split Sections: Recent Requests & On Leave Today
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            final recentCard = _buildRecentRequestsCard(recentRequests);
            final onLeaveCard = _buildOnLeaveTodayCard(onLeaveTodayRequests, employees);

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: recentCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: onLeaveCard),
                ],
              );
            }

            return Column(
              children: [
                recentCard,
                const SizedBox(height: 20),
                onLeaveCard,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    IconData icon,
    Color bgIconColor,
    Color iconColor,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgIconColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsCard(List<LeaveRequest> recentRequests) {
    final displayList = recentRequests.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => setState(() => _activeTab = LeaveTab.requests),
                child: const Row(
                  children: [
                    Text('View all', style: TextStyle(fontSize: 13, color: Color(0xFF0D8A4E), fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Color(0xFF0D8A4E)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (displayList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No leave requests found.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final req = displayList[index];
                return _buildRecentRequestRow(req);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestRow(LeaveRequest req) {
    final initials = _getInitials(req.employeeName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE2E8F0),
            child: Text(
              initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req.employeeName} (${req.employeeCustomId.isNotEmpty ? req.employeeCustomId : 'EMP'})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${req.leaveType} · ${_formatDateDisplay(req.fromDate)} · ${req.numDays.toStringAsFixed(0)} day${req.numDays > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (req.status == 'Pending') ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _handleDenyRequest(req),
              child: const Text('Deny', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D8A4E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: () => _handleApproveRequest(req),
              child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ] else ...[
            _buildStatusBadge(req.status),
          ],
        ],
      ),
    );
  }

  Widget _buildOnLeaveTodayCard(List<LeaveRequest> onLeaveTodayRequests, List<Employee> employees) {
    final todayFormatted = DateFormat('d MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On Leave Today — $todayFormatted',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          if (onLeaveTodayRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No employees on leave today.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: onLeaveTodayRequests.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final req = onLeaveTodayRequests[index];
                final emp = employees.firstWhere(
                  (e) => e.id == req.employeeId,
                  orElse: () => Employee(
                    id: req.employeeId,
                    employeeId: req.employeeCustomId,
                    firstName: req.employeeName,
                    lastName: '',
                    emailAddress: '',
                    phoneNumber: '',
                    gender: '',
                    dob: '',
                    organizationName: '',
                    department: 'General',
                    designation: '',
                    employmentType: '',
                    joiningDate: '',
                    status: 'Active',
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          _getInitials(req.employeeName),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.employeeName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              '${emp.department} · ${req.leaveType}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: click any date in the Calendar tab to see every employee on leave that day.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. REQUESTS TAB
  // ---------------------------------------------------------------------------
  Widget _buildRequestsTab(
    List<LeaveRequest> allRequests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    // Apply filters
    final filtered = allRequests.where((req) {
      if (_filterEmployeeId != null && req.employeeId != _filterEmployeeId) return false;
      if (_filterStatus != 'All Status' && req.status != _filterStatus) return false;
      if (_filterLeaveType != 'All Leave Types' && req.leaveType != _filterLeaveType) return false;

      if (_filterDepartment != 'All Departments' || _filterDesignation != 'All Designations') {
        final emp = employees.firstWhere(
          (e) => e.id == req.employeeId,
          orElse: () => Employee(
            id: 0,
            employeeId: '',
            firstName: '',
            lastName: '',
            emailAddress: '',
            phoneNumber: '',
            gender: '',
            dob: '',
            organizationName: '',
            department: '',
            designation: '',
            employmentType: '',
            joiningDate: '',
            status: 'Active',
          ),
        );

        if (_filterDepartment != 'All Departments' && emp.department != _filterDepartment) {
          return false;
        }

        if (_filterDesignation != 'All Designations' && emp.designation != _filterDesignation) {
          return false;
        }
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = req.employeeName.toLowerCase().contains(q);
        final matchId = req.employeeCustomId.toLowerCase().contains(q);
        final matchType = req.leaveType.toLowerCase().contains(q);
        if (!matchName && !matchId && !matchType) return false;
      }

      return true;
    }).toList();

    final deptOptions = [
      'All Departments',
      ...{
        ...Employee.departmentOptions,
        ...employees.map((e) => e.department).where((d) => d.isNotEmpty),
      }
    ];

    final designationOptions = [
      'All Designations',
      ...{
        ...Employee.designationOptions,
        ...employees.map((e) => e.designation).where((d) => d.isNotEmpty),
      }
    ];

    final typeOptions = {'All Leave Types', ...leaveTypes.map((t) => t.name)};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isExtraWide = constraints.maxWidth > 1100;
                  final isWide = constraints.maxWidth > 700;

                  final searchBox = SizedBox(
                    height: 40,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search by employee name or ID...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  );

                  final empDropdown = _buildSimpleDropdown<int?>(
                    value: _filterEmployeeId,
                    hint: 'All Employees',
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Employees', overflow: TextOverflow.ellipsis)),
                      ...employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.fullName, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _filterEmployeeId = v),
                  );

                  final statusDropdown = _buildSimpleDropdown<String>(
                    value: _filterStatus,
                    items: ['All Status', 'Pending', 'Approved', 'Denied']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterStatus = v ?? 'All Status'),
                  );

                  final typeDropdown = _buildSimpleDropdown<String>(
                    value: _filterLeaveType,
                    items: typeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterLeaveType = v ?? 'All Leave Types'),
                  );

                  final deptDropdown = _buildSimpleDropdown<String>(
                    value: _filterDepartment,
                    items: deptOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterDepartment = v ?? 'All Departments'),
                  );

                  final desigDropdown = _buildSimpleDropdown<String>(
                    value: _filterDesignation,
                    items: designationOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterDesignation = v ?? 'All Designations'),
                  );

                  if (isExtraWide) {
                    return Row(
                      children: [
                        Expanded(flex: 2, child: searchBox),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: empDropdown),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: statusDropdown),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: typeDropdown),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: deptDropdown),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: desigDropdown),
                      ],
                    );
                  }

                  if (isWide) {
                    return Column(
                      children: [
                        searchBox,
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: empDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: statusDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: typeDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: deptDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: desigDropdown),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      searchBox,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: empDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: statusDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: typeDropdown),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: deptDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: desigDropdown),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Requests List Cards
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No leave requests match the selected filters.', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final req = filtered[index];
              final emp = employees.firstWhere(
                (e) => e.id == req.employeeId,
                orElse: () => Employee(
                  id: req.employeeId,
                  employeeId: req.employeeCustomId,
                  firstName: req.employeeName,
                  lastName: '',
                  emailAddress: '',
                  phoneNumber: '',
                  gender: '',
                  dob: '',
                  organizationName: '',
                  department: 'Engineering',
                  designation: '',
                  employmentType: '',
                  joiningDate: '',
                  status: 'Active',
                ),
              );
              final typeObj = leaveTypes.firstWhere(
                (t) => t.name.toLowerCase() == req.leaveType.toLowerCase(),
                orElse: () => LeaveType(id: 0, name: req.leaveType, description: '', colorHex: '#6366F1'),
              );

              return _buildRequestCard(req, emp, typeObj);
            },
          ),
      ],
    );
  }

  Widget _buildRequestCard(LeaveRequest req, Employee emp, LeaveType leaveTypeObj) {
    final color = _parseHexColor(leaveTypeObj.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  _getInitials(req.employeeName),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          req.employeeName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${req.employeeCustomId.isNotEmpty ? req.employeeCustomId : 'EMP'} · ${emp.department}${emp.designation.isNotEmpty ? ' • ${emp.designation}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            req.leaveType,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_formatDateDisplay(req.fromDate)} — ${_formatDateDisplay(req.toDate)} · ${req.numDays.toStringAsFixed(0)} day${req.numDays > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reason: "${req.reason.isNotEmpty ? req.reason : 'No reason specified'}"',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave balance: 6 of 12 ${req.leaveType.toLowerCase()} days remaining',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showAuditHistoryDialog(req),
                      child: const Text(
                        'View audit history',
                        style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(req.status),
                  const SizedBox(height: 14),
                  if (req.status == 'Pending')
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _handleDenyRequest(req),
                          child: const Text('Deny', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D8A4E),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          onPressed: () => _handleApproveRequest(req),
                          child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAuditHistoryDialog(LeaveRequest req) {
    showDialog(
      context: context,
      builder: (ctx) {
        final logsAsync = ref.watch(leaveAuditLogsProvider(req.id));
        return AlertDialog(
          title: Text('Audit History - ${req.employeeName} (${req.leaveType})'),
          content: SizedBox(
            width: 450,
            child: logsAsync.when(
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e'),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No audit logs available for this request.'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      leading: const Icon(Icons.history, size: 20, color: Colors.blueGrey),
                      title: Text(log['action'] as String? ?? 'Action'),
                      subtitle: Text('By: ${log['performed_by'] ?? 'System'} · ${log['timestamp'] ?? ''}\n${log['details'] ?? ''}'),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. CALENDAR TAB
  // ---------------------------------------------------------------------------
  Widget _buildCalendarTab(
    List<LeaveRequest> allRequests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    final filteredRequests = allRequests.where((req) {
      if (_filterEmployeeId != null && req.employeeId != _filterEmployeeId) return false;
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 950;

        final calendarView = _buildCalendarGrid(filteredRequests, employees, leaveTypes);
        final sidePanel = _buildCalendarDayDetailPanel(filteredRequests, employees, leaveTypes);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: calendarView),
              const SizedBox(width: 20),
              Expanded(flex: 1, child: sidePanel),
            ],
          );
        }

        return Column(
          children: [
            calendarView,
            const SizedBox(height: 20),
            sidePanel,
          ],
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    List<LeaveRequest> requests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    final monthStr = DateFormat('MMMM yyyy').format(_focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final totalGridCells = startingWeekday + daysInMonth;
    final rowCount = (totalGridCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Month Switcher & Employee Filter Dropdown
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
              ),
              Text(
                monthStr,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                child: _buildSimpleDropdown<int?>(
                  value: _filterEmployeeId,
                  hint: 'All Employees',
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All Employees')),
                    ...employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.fullName))),
                  ],
                  onChanged: (v) => setState(() => _filterEmployeeId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days Header (Sun - Sat)
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),

          // Grid Days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              final dayNum = index - startingWeekday + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }

              final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final isSelected = cellDate.year == _selectedCalendarDate.year &&
                  cellDate.month == _selectedCalendarDate.month &&
                  cellDate.day == _selectedCalendarDate.day;

              // Find requests matching this cell
              final cellDateStr = '${cellDate.day.toString().padLeft(2, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.year}';
              final matching = requests.where((r) {
                if (r.status == 'Approved' && r.approvedDates.contains(cellDateStr)) return true;
                if (r.status == 'Pending') {
                  final f = _parseDate(r.fromDate);
                  final t = _parseDate(r.toDate);
                  if (f != null && t != null) {
                    final normCell = DateTime(cellDate.year, cellDate.month, cellDate.day);
                    final normF = DateTime(f.year, f.month, f.day);
                    final normT = DateTime(t.year, t.month, t.day);
                    return (normCell.isAfter(normF) || normCell.isAtSameMomentAs(normF)) &&
                        (normCell.isBefore(normT) || normCell.isAtSameMomentAs(normT));
                  }
                }
                return false;
              }).toList();

              return InkWell(
                onTap: () => setState(() => _selectedCalendarDate = cellDate),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0D8A4E) : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? const Color(0xFF0D8A4E) : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ...matching.take(2).map((req) {
                              final typeObj = leaveTypes.firstWhere(
                                (t) => t.name.toLowerCase() == req.leaveType.toLowerCase(),
                                orElse: () => LeaveType(id: 0, name: req.leaveType, description: '', colorHex: req.status == 'Pending' ? '#F59E0B' : '#6366F1'),
                              );
                              final chipColor = req.status == 'Pending' ? const Color(0xFFFEF3C7) : _parseHexColor(typeObj.colorHex).withValues(alpha: 0.15);
                              final textColor = req.status == 'Pending' ? const Color(0xFFD97706) : _parseHexColor(typeObj.colorHex);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  req.employeeName.split(' ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              );
                            }),
                            if (matching.length > 2)
                              Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '+${matching.length - 2} more',
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Legend Bar at Bottom
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF0D8A4E), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Approved', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const Spacer(),
              const Text('Click any date to see who\'s on leave', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayDetailPanel(
    List<LeaveRequest> requests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    final cellDateStr = '${_selectedCalendarDate.day.toString().padLeft(2, '0')}-${_selectedCalendarDate.month.toString().padLeft(2, '0')}-${_selectedCalendarDate.year}';
    final formattedDateTitle = DateFormat('MMM d, yyyy').format(_selectedCalendarDate);

    final dayRequests = requests.where((r) {
      if (r.status == 'Approved' && r.approvedDates.contains(cellDateStr)) return true;
      if (r.status == 'Pending') {
        final f = _parseDate(r.fromDate);
        final t = _parseDate(r.toDate);
        if (f != null && t != null) {
          final normCell = DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, _selectedCalendarDate.day);
          final normF = DateTime(f.year, f.month, f.day);
          final normT = DateTime(t.year, t.month, t.day);
          return (normCell.isAfter(normF) || normCell.isAtSameMomentAs(normF)) &&
              (normCell.isBefore(normT) || normCell.isAtSameMomentAs(normT));
        }
      }
      return false;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDateTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          Text(
            '${dayRequests.length} employee${dayRequests.length == 1 ? '' : 's'} on leave',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (dayRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No employees on leave for this date.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayRequests.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final req = dayRequests[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFCBD5E1),
                              child: Text(
                                _getInitials(req.employeeName),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                req.employeeName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),
                            _buildStatusBadge(req.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${req.leaveType} · ${_formatDateDisplay(req.fromDate)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                        if (req.reason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: "${req.reason}"',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. PERMISSIONS & LEAVE TYPES TAB
  // ---------------------------------------------------------------------------
  Widget _buildPermissionsTab(List<Employee> employees, List<LeaveType> leaveTypes) {
    final overridesAsync = ref.watch(employeeOverridesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Leave Types Table + Add Leave Type Button
        _buildLeaveTypesSection(leaveTypes),
        const SizedBox(height: 28),

        // Section 2: Employee Overrides
        overridesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading overrides: $e'),
          data: (overrides) => _buildEmployeeOverridesSection(overrides, employees, leaveTypes),
        ),
      ],
    );
  }

  Widget _buildLeaveTypesSection(List<LeaveType> leaveTypes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Types',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Types shown on employee requests and on the calendar legend.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8A4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _showAddLeaveTypeDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Leave Types Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(2.0),
              3: FlexColumnWidth(2.0),
              4: FlexColumnWidth(1.2),
              5: FlexColumnWidth(1.2),
            },
            children: [
              // Header Row
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                children: ['TYPE', 'ANNUAL ALLOCATION', 'CARRY FORWARD', 'CALENDAR COLOR', 'STATUS', 'ACTIONS']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          child: Text(
                            h,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                        ))
                    .toList(),
              ),

              // Rows
              ...leaveTypes.map((lt) {
                final color = _parseHexColor(lt.colorHex);

                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  children: [
                    // Type Name
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      child: Text(
                        lt.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ),
                    // Annual Allocation
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      child: Text(
                        '${lt.annualAllocation.toStringAsFixed(0)} days / year',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                    // Carry Forward
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      child: Text(
                        lt.carryForward,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                    // Editable Calendar Color Dot & Picker Action
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      child: InkWell(
                        onTap: () => _showEditColorDialog(context, lt),
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getColorLabel(lt.colorHex),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    // Status Switch Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      child: Switch(
                        value: lt.isActive,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (val) async {
                          final updated = lt.copyWith(isActive: val);
                          await ref.read(leaveRepositoryProvider).updateLeaveType(updated);
                          ref.invalidate(leaveTypesProvider);
                        },
                      ),
                    ),
                    // Actions: Edit / Delete
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF2563EB)),
                            tooltip: 'Edit Color',
                            onPressed: () => _showEditColorDialog(context, lt),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                            tooltip: 'Delete Leave Type',
                            onPressed: () async {
                              await ref.read(leaveRepositoryProvider).deleteLeaveType(lt.id);
                              ref.invalidate(leaveTypesProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddLeaveTypeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final allocCtrl = TextEditingController(text: '12');
    String carryForward = 'Up to 3 days';
    String selectedHex = '#6366F1';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add New Leave Type', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Type Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Maternity Leave, Paternity Leave', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(hintText: 'Short description...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Annual Allocation (Days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: allocCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Carry Forward', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: carryForward,
                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                items: ['Not allowed', 'Up to 3 days', 'Up to 5 days', 'Up to 10 days', 'Unlimited']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (v) => setDialogState(() => carryForward = v ?? carryForward),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Calendar Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    _buildColorPalettePicker(selectedHex, (newHex) {
                      setDialogState(() => selectedHex = newHex);
                    }),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Status', style: TextStyle(fontSize: 13)),
                      value: isActive,
                      activeColor: const Color(0xFF0D8A4E),
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D8A4E)),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final alloc = double.tryParse(allocCtrl.text.trim()) ?? 12.0;

                  final newType = LeaveType(
                    id: 0,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    annualAllocation: alloc,
                    carryForward: carryForward,
                    colorHex: selectedHex,
                    isActive: isActive,
                  );

                  await ref.read(leaveRepositoryProvider).addLeaveType(newType);
                  ref.invalidate(leaveTypesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Leave Type', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditColorDialog(BuildContext context, LeaveType leaveType) {
    String currentHex = leaveType.colorHex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Edit Color: ${leaveType.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a new color for calendar & badges:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                _buildColorPalettePicker(currentHex, (hex) {
                  setDialogState(() => currentHex = hex);
                }),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D8A4E)),
                onPressed: () async {
                  final updated = leaveType.copyWith(colorHex: currentHex);
                  await ref.read(leaveRepositoryProvider).updateLeaveType(updated);
                  ref.invalidate(leaveTypesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Update Color', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildColorPalettePicker(String currentHex, Function(String) onSelectHex) {
    final colors = [
      {'name': 'Indigo', 'hex': '#6366F1'},
      {'name': 'Teal', 'hex': '#14B8A6'},
      {'name': 'Green', 'hex': '#22C55E'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Purple', 'hex': '#8B5CF6'},
      {'name': 'Rose', 'hex': '#F43F5E'},
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Emerald', 'hex': '#10B981'},
      {'name': 'Cyan', 'hex': '#06B6D4'},
      {'name': 'Orange', 'hex': '#F97316'},
      {'name': 'Pink', 'hex': '#EC4899'},
      {'name': 'Slate', 'hex': '#64748B'},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        final hex = c['hex']!;
        final isSelected = hex.toLowerCase() == currentHex.toLowerCase();
        final color = _parseHexColor(hex);

        return InkWell(
          onTap: () => onSelectHex(hex),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  c['name']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getColorLabel(String hex) {
    switch (hex.toUpperCase()) {
      case '#6366F1':
        return 'Indigo';
      case '#14B8A6':
        return 'Teal';
      case '#22C55E':
        return 'Green';
      case '#F59E0B':
        return 'Amber';
      case '#8B5CF6':
        return 'Purple';
      case '#F43F5E':
        return 'Rose';
      case '#3B82F6':
        return 'Blue';
      case '#10B981':
        return 'Emerald';
      case '#06B6D4':
        return 'Cyan';
      case '#F97316':
        return 'Orange';
      case '#EC4899':
        return 'Pink';
      case '#64748B':
        return 'Slate';
      default:
        return hex;
    }
  }

  Widget _buildEmployeeOverridesSection(
    List<Map<String, dynamic>> overrides,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Overrides',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Per-employee exceptions to the defaults above (e.g. extra sick days for a specific person).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _showAddOverrideDialog(context, employees, leaveTypes),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add Override', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (overrides.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No employee overrides defined.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3.0),
                1: FlexColumnWidth(3.0),
                2: FlexColumnWidth(3.0),
                3: FlexColumnWidth(1.0),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  children: ['EMPLOYEE', 'OVERRIDE', 'REASON', 'ACTIONS']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            child: Text(
                              h,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ))
                      .toList(),
                ),
                ...overrides.map((ov) {
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        child: Text(
                          '${ov['employee_name']} (${ov['employee_custom_id']})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        child: Text(
                          '${ov['leave_type']}: ${ov['override_days']} days',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        child: Text(
                          ov['reason'] as String? ?? 'Contract terms',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          onPressed: () async {
                            final id = ov['id'];
                            if (id is int) {
                              await ref.read(leaveRepositoryProvider).deleteEmployeeOverride(id);
                              ref.invalidate(employeeOverridesProvider);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  void _showAddOverrideDialog(
    BuildContext context,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    Employee? selectedEmp = employees.isNotEmpty ? employees.first : null;
    LeaveType? selectedType = leaveTypes.isNotEmpty ? leaveTypes.first : null;
    final daysCtrl = TextEditingController(text: '12');
    final reasonCtrl = TextEditingController(text: 'Contract terms');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Employee Override', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Employee>(
                    value: selectedEmp,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                    items: employees
                        .map((e) => DropdownMenuItem(value: e, child: Text('${e.fullName} (${e.employeeId})')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedEmp = v),
                  ),
                  const SizedBox(height: 14),
                  const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<LeaveType>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                    items: leaveTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v),
                  ),
                  const SizedBox(height: 14),
                  const Text('Override Days Allowed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D8A4E)),
                onPressed: () async {
                  if (selectedEmp == null || selectedType == null) return;
                  final days = double.tryParse(daysCtrl.text.trim()) ?? 12.0;

                  await ref.read(leaveRepositoryProvider).addEmployeeOverride({
                    'employee_id': selectedEmp!.id,
                    'employee_name': selectedEmp!.fullName,
                    'employee_custom_id': selectedEmp!.employeeId,
                    'leave_type': selectedType!.name,
                    'override_days': days,
                    'reason': reasonCtrl.text.trim(),
                  });
                  ref.invalidate(employeeOverridesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Override', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. COMMON UTILITY HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildSimpleDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 12)) : null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text = status;

    switch (status) {
      case 'Approved':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        text = '✓ Approved';
        break;
      case 'Denied':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        text = '✕ Denied';
        break;
      case 'Pending':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        text = '⏳ Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return 'EM';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _handleApproveRequest(LeaveRequest req) async {
    final currentEmp = ref.read(currentEmployeeProvider);
    final adminName = currentEmp?.fullName ?? 'Admin';
    await ref.read(leaveRepositoryProvider).approveLeaveRequest(req.id, adminName);
    ref.invalidate(allLeaveRequestsProvider);
    ref.invalidate(leaveRequestsProvider);
  }

  Future<void> _handleDenyRequest(LeaveRequest req) async {
    final currentEmp = ref.read(currentEmployeeProvider);
    final adminName = currentEmp?.fullName ?? 'Admin';
    await ref.read(leaveRepositoryProvider).denyLeaveRequest(req.id, adminName);
    ref.invalidate(allLeaveRequestsProvider);
    ref.invalidate(leaveRequestsProvider);
  }
}
