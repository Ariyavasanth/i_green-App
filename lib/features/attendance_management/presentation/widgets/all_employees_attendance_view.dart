import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/domain/attendance_status_helper.dart';
import '../../../employee/domain/employee.dart';
import '../../../leave/domain/leave_request.dart';
import '../../../on_duty/domain/on_duty_assignment.dart';
import '../../../permission/domain/permission_request.dart';
import '../../../site_visit_attendance/domain/site_visit_record.dart';

class AllEmployeesAttendanceView extends StatefulWidget {
  const AllEmployeesAttendanceView({
    super.key,
    required this.allEmployees,
    required this.staticRecords,
    required this.siteVisits,
    this.leaves,
    this.onDutyAssignments,
    this.holidays,
    this.permissions,
    required this.focusedMonth,
    this.onMonthChanged,
    this.isMobile = false,
    this.onOpenAttendanceCorrection,
    this.onOpenSiteVisitDetails,
    this.onOpenOfficeDetails,
    this.onAddOfficeEntry,
    this.onAddSiteEntry,
    this.onAssignOnDuty,
  });

  final List<Employee> allEmployees;
  final List<AttendanceRecord> staticRecords;
  final List<SiteVisitRecord> siteVisits;
  final List<LeaveRequest>? leaves;
  final List<OnDutyAssignment>? onDutyAssignments;
  final List<String>? holidays;
  final List<PermissionRequest>? permissions;
  final DateTime focusedMonth;
  final ValueChanged<DateTime>? onMonthChanged;
  final bool isMobile;

  final void Function(
    Employee employee,
    DateTime date,
    AttendanceRecord? record,
    AttendanceStatusInfo? statusInfo,
  )? onOpenAttendanceCorrection;

  final void Function(SiteVisitRecord visit)? onOpenSiteVisitDetails;

  final void Function(
    Employee employee,
    DateTime date,
    AttendanceRecord? record,
    AttendanceStatusInfo? statusInfo,
  )? onOpenOfficeDetails;

  final void Function(AttendanceRecord? record, int? empId, String? dateStr)? onAddOfficeEntry;
  final void Function(SiteVisitRecord? visit)? onAddSiteEntry;
  final void Function(Employee? employee)? onAssignOnDuty;

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkSlate = Color(0xFF414A51);

  @override
  State<AllEmployeesAttendanceView> createState() => _AllEmployeesAttendanceViewState();
}

class _AllEmployeesAttendanceViewState extends State<AllEmployeesAttendanceView> {
  late DateTime _selectedDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedDepartment = 'All Departments';
  String _selectedScheduleType = 'All Schedules';
  String _selectedStatusFilter = 'All';
  bool _isTableView = false;

  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.focusedMonth.year == now.year && widget.focusedMonth.month == now.month) {
      _selectedDate = DateTime(now.year, now.month, now.day);
    } else {
      _selectedDate = DateTime(widget.focusedMonth.year, widget.focusedMonth.month, 1);
    }
  }

  @override
  void didUpdateWidget(covariant AllEmployeesAttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedMonth.year != widget.focusedMonth.year ||
        oldWidget.focusedMonth.month != widget.focusedMonth.month) {
      final now = DateTime.now();
      if (widget.focusedMonth.year == now.year && widget.focusedMonth.month == now.month) {
        _selectedDate = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDate = DateTime(widget.focusedMonth.year, widget.focusedMonth.month, 1);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static DateTime? _parseDate(String dateStr) {
    if (dateStr.trim().isEmpty) return null;
    final clean = dateStr.trim().replaceAll('/', '-');
    final dt = DateTime.tryParse(clean);
    if (dt != null) return dt;
    final parts = clean.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else if (parts[2].length == 4) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }
    return null;
  }

  static bool _isSameDay(String dateStr, DateTime target) {
    final dt = _parseDate(dateStr);
    if (dt == null) return false;
    return dt.year == target.year && dt.month == target.month && dt.day == target.day;
  }

  static bool _isSameMonth(String dateStr, DateTime target) {
    final dt = _parseDate(dateStr);
    if (dt == null) return false;
    return dt.year == target.year && dt.month == target.month;
  }

  AttendanceRecord? _findOfficeRecord(Employee emp, DateTime date) {
    for (final r in widget.staticRecords) {
      if (!_isSameDay(r.date, date)) continue;
      if (r.employeeId != 0 && r.employeeId == emp.id) return r;
      if (r.employeeCode.isNotEmpty && emp.employeeId.isNotEmpty &&
          r.employeeCode.trim().toUpperCase() == emp.employeeId.trim().toUpperCase()) {
        return r;
      }
      if (r.employeeName.trim().isNotEmpty && emp.fullName.trim().isNotEmpty &&
          r.employeeName.trim().toLowerCase() == emp.fullName.trim().toLowerCase()) {
        return r;
      }
    }
    return null;
  }

  List<SiteVisitRecord> _findSiteVisits(Employee emp, DateTime date) {
    final list = <SiteVisitRecord>[];
    for (final v in widget.siteVisits) {
      if (!_isSameDay(v.visitDate, date)) continue;
      if (v.employeeId != 0 && v.employeeId == emp.id) {
        list.add(v);
        continue;
      }
      if (v.employeeName.trim().isNotEmpty && emp.fullName.trim().isNotEmpty &&
          v.employeeName.trim().toLowerCase() == emp.fullName.trim().toLowerCase()) {
        list.add(v);
      }
    }
    return list;
  }

  List<AttendanceRecord> _getMonthlyOfficeRecords(Employee emp) {
    final list = <AttendanceRecord>[];
    for (final r in widget.staticRecords) {
      if (!_isSameMonth(r.date, widget.focusedMonth)) continue;
      if ((r.employeeId != 0 && r.employeeId == emp.id) ||
          (r.employeeCode.isNotEmpty && emp.employeeId.isNotEmpty &&
              r.employeeCode.trim().toUpperCase() == emp.employeeId.trim().toUpperCase()) ||
          (r.employeeName.trim().isNotEmpty && emp.fullName.trim().isNotEmpty &&
              r.employeeName.trim().toLowerCase() == emp.fullName.trim().toLowerCase())) {
        list.add(r);
      }
    }
    return list;
  }

  List<SiteVisitRecord> _getMonthlySiteVisits(Employee emp) {
    final list = <SiteVisitRecord>[];
    for (final v in widget.siteVisits) {
      if (!_isSameMonth(v.visitDate, widget.focusedMonth)) continue;
      if ((v.employeeId != 0 && v.employeeId == emp.id) ||
          (v.employeeName.trim().isNotEmpty && emp.fullName.trim().isNotEmpty &&
              v.employeeName.trim().toLowerCase() == emp.fullName.trim().toLowerCase())) {
        list.add(v);
      }
    }
    return list;
  }

  String _resolveUnifiedStatus({
    required Employee employee,
    required AttendanceRecord? officeRecord,
    required List<SiteVisitRecord> daySiteVisits,
    required AttendanceStatusInfo? statusInfo,
    required DateTime date,
  }) {
    final hasOfficeCheckIn = officeRecord != null &&
        (officeRecord.effectiveCheckInTime.isNotEmpty ||
         officeRecord.status.toLowerCase() == 'present' ||
         officeRecord.status.toLowerCase() == 'checked out' ||
         officeRecord.status.toLowerCase() == 'late');

    final hasSiteVisits = daySiteVisits.isNotEmpty;

    if (hasOfficeCheckIn && hasSiteVisits) {
      return 'Office & Site';
    }
    if (hasOfficeCheckIn) {
      if (officeRecord.status.toLowerCase().contains('late')) {
        return 'Late (Office)';
      }
      return 'Office Present';
    }
    if (hasSiteVisits) {
      return 'Site Active (${daySiteVisits.length})';
    }

    if (statusInfo == AttendanceStatusInfo.onDuty) return 'On Duty';
    if (statusInfo == AttendanceStatusInfo.onLeave) return 'On Leave';
    if (statusInfo == AttendanceStatusInfo.holiday) return 'Holiday';
    if (statusInfo == AttendanceStatusInfo.weeklyOff) return 'Weekly Off';
    if (statusInfo == AttendanceStatusInfo.beforeJoining) return 'Before Joining';

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) {
      return 'Not Checked In';
    }
    return 'Absent';
  }

  Color _getStatusBgColor(String status) {
    if (status.contains('Office & Site')) return const Color(0xFFDCFCE7);
    if (status.contains('Office Present')) return const Color(0xFFDCFCE7);
    if (status.contains('Late')) return const Color(0xFFFFEDD5);
    if (status.contains('Site Active')) return const Color(0xFFCCFBF1);
    if (status == 'On Duty') return const Color(0xFFE0F2FE);
    if (status == 'On Leave') return const Color(0xFFFEF9C3);
    if (status == 'Holiday') return const Color(0xFFF3E8FF);
    if (status == 'Weekly Off') return const Color(0xFFF1F5F9);
    if (status == 'Before Joining') return const Color(0xFFF1F5F9);
    if (status == 'Not Checked In') return const Color(0xFFFFE4E6);
    return const Color(0xFFFEE2E2);
  }

  Color _getStatusTextColor(String status) {
    if (status.contains('Office & Site')) return const Color(0xFF15803D);
    if (status.contains('Office Present')) return const Color(0xFF16A34A);
    if (status.contains('Late')) return const Color(0xFFEA580C);
    if (status.contains('Site Active')) return const Color(0xFF0F766E);
    if (status == 'On Duty') return const Color(0xFF0284C7);
    if (status == 'On Leave') return const Color(0xFFCA8A04);
    if (status == 'Holiday') return const Color(0xFF7C3AED);
    if (status == 'Weekly Off') return const Color(0xFF64748B);
    if (status == 'Before Joining') return const Color(0xFF94A3B8);
    if (status == 'Not Checked In') return const Color(0xFFE11D48);
    return const Color(0xFFDC2626);
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('Office & Site')) return Icons.domain_verification_rounded;
    if (status.contains('Office Present')) return Icons.storefront_outlined;
    if (status.contains('Late')) return Icons.access_time_rounded;
    if (status.contains('Site Active')) return Icons.location_on_outlined;
    if (status == 'On Duty') return Icons.badge_outlined;
    if (status == 'On Leave') return Icons.work_off_outlined;
    if (status == 'Holiday') return Icons.celebration_outlined;
    if (status == 'Weekly Off') return Icons.weekend_outlined;
    if (status == 'Before Joining') return Icons.history_toggle_off_rounded;
    if (status == 'Not Checked In') return Icons.radio_button_unchecked_rounded;
    return Icons.cancel_outlined;
  }

  List<Employee> _filterEmployees() {
    return widget.allEmployees.where((emp) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = emp.fullName.toLowerCase().contains(q);
        final matchesCode = emp.employeeId.toLowerCase().contains(q);
        final matchesDept = emp.department.toLowerCase().contains(q);
        final matchesDesig = emp.designation.toLowerCase().contains(q);
        if (!matchesName && !matchesCode && !matchesDept && !matchesDesig) {
          return false;
        }
      }

      if (_selectedDepartment != 'All Departments' &&
          emp.department.trim().toLowerCase() != _selectedDepartment.trim().toLowerCase()) {
        return false;
      }

      final isFixed = emp.isStaticEmployee || emp.workScheduleType.trim().toLowerCase() == 'fixed schedule';
      final isFlexible = emp.isDynamicEmployee || emp.workScheduleType.trim().toLowerCase() == 'flexible schedule';
      if (_selectedScheduleType == 'Office (Fixed)' && (!isFixed || isFlexible)) {
        return false;
      }
      if (_selectedScheduleType == 'Site (Flexible)' && (!isFlexible || isFixed)) {
        return false;
      }
      if (_selectedScheduleType == 'Hybrid / Dual' && !(isFixed && isFlexible)) {
        return false;
      }

      if (_selectedStatusFilter != 'All') {
        final officeRec = _findOfficeRecord(emp, _selectedDate);
        final siteVisits = _findSiteVisits(emp, _selectedDate);
        final statusInfo = AttendanceStatusHelper.resolveStatus(
          employee: emp,
          date: _selectedDate,
          record: officeRec,
          leaves: widget.leaves,
          onDutyAssignments: widget.onDutyAssignments,
          holidays: widget.holidays,
          permissions: widget.permissions,
        );
        final unifiedStatus = _resolveUnifiedStatus(
          employee: emp,
          officeRecord: officeRec,
          daySiteVisits: siteVisits,
          statusInfo: statusInfo,
          date: _selectedDate,
        );

        if (_selectedStatusFilter == 'Office & Site' && !unifiedStatus.contains('Office & Site')) {
          return false;
        }
        if (_selectedStatusFilter == 'Office Present' && !unifiedStatus.contains('Office Present')) {
          return false;
        }
        if (_selectedStatusFilter == 'Site Active' && !unifiedStatus.contains('Site Active')) {
          return false;
        }
        if (_selectedStatusFilter == 'On Duty' && unifiedStatus != 'On Duty') {
          return false;
        }
        if (_selectedStatusFilter == 'On Leave' && unifiedStatus != 'On Leave') {
          return false;
        }
        if (_selectedStatusFilter == 'Absent' && unifiedStatus != 'Absent') {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> _extractDepartments() {
    final depts = <String>{'All Departments'};
    for (final emp in widget.allEmployees) {
      if (emp.department.trim().isNotEmpty) {
        depts.add(emp.department.trim());
      }
    }
    return depts.toList()..sort();
  }

  void _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9CC70A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 1;
        if (picked.year != widget.focusedMonth.year || picked.month != widget.focusedMonth.month) {
          widget.onMonthChanged?.call(DateTime(picked.year, picked.month, 1));
        }
      });
    }
  }

  void _openUnifiedDetailsDialog(Employee emp) {
    final officeRec = _findOfficeRecord(emp, _selectedDate);
    final daySiteVisits = _findSiteVisits(emp, _selectedDate);
    final statusInfo = AttendanceStatusHelper.resolveStatus(
      employee: emp,
      date: _selectedDate,
      record: officeRec,
      leaves: widget.leaves,
      onDutyAssignments: widget.onDutyAssignments,
      holidays: widget.holidays,
      permissions: widget.permissions,
    );
    final unifiedStatus = _resolveUnifiedStatus(
      employee: emp,
      officeRecord: officeRec,
      daySiteVisits: daySiteVisits,
      statusInfo: statusInfo,
      date: _selectedDate,
    );

    final monthOffice = _getMonthlyOfficeRecords(emp);
    final monthVisits = _getMonthlySiteVisits(emp);
    double totalMonthHours = 0.0;
    for (final r in monthOffice) {
      totalMonthHours += r.totalHours;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(emp, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id}'} • ${emp.department} • ${emp.designation}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusBgColor(unifiedStatus),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getStatusIcon(unifiedStatus), size: 13, color: _getStatusTextColor(unifiedStatus)),
                                  const SizedBox(width: 4),
                                  Text(
                                    unifiedStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusTextColor(unifiedStatus),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 28),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.storefront_outlined, size: 18, color: AllEmployeesAttendanceView.darkSlate),
                                    SizedBox(width: 8),
                                    Text(
                                      'Office Attendance Record',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                if (officeRec != null)
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      widget.onOpenAttendanceCorrection?.call(emp, _selectedDate, officeRec, statusInfo);
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 14, color: AllEmployeesAttendanceView.darkSlate),
                                        SizedBox(width: 4),
                                        Text('Edit / Correct', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.darkSlate)),
                                      ],
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      widget.onAddOfficeEntry?.call(null, emp.id, DateFormat('dd-MM-yyyy').format(_selectedDate));
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.add, size: 14, color: AllEmployeesAttendanceView.primaryGreen),
                                        SizedBox(width: 4),
                                        Text('Log Office Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.primaryGreen)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (officeRec != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailTile(
                                      label: 'Check-In Time',
                                      value: officeRec.effectiveCheckInTime.isNotEmpty
                                          ? officeRec.formattedCheckInTime
                                          : 'Not Logged',
                                      subvalue: officeRec.effectiveCheckInVerification.isNotEmpty
                                          ? officeRec.effectiveCheckInVerification
                                          : null,
                                      icon: Icons.login_rounded,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildDetailTile(
                                      label: 'Check-Out Time',
                                      value: officeRec.checkOutTime.isNotEmpty
                                          ? officeRec.formattedCheckOutTime
                                          : 'In Progress / None',
                                      subvalue: officeRec.checkOutVerificationStatus.isNotEmpty
                                          ? officeRec.checkOutVerificationStatus
                                          : null,
                                      icon: Icons.logout_rounded,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildDetailTile(
                                      label: 'Total Hours',
                                      value: officeRec.totalHours > 0
                                          ? '${officeRec.totalHours.toStringAsFixed(2)} hrs'
                                          : '--',
                                      subvalue: officeRec.status,
                                      icon: Icons.timelapse_rounded,
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                              if (officeRec.sessions.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text('Session Breakdown:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                for (final s in officeRec.sessions)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(color: AllEmployeesAttendanceView.primaryGreen, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${s.type.toUpperCase()}: ${s.checkInTime} – ${s.checkOutTime.isNotEmpty ? s.checkOutTime : 'Active'} (${s.durationHours.toStringAsFixed(1)} hrs)',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              if (officeRec.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Notes: ${officeRec.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                              ],
                            ] else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No office attendance check-in logged for this date.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF0F766E)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Site Visit Records (${daySiteVisits.length})',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    widget.onAddSiteEntry?.call(null);
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.add_location_alt_outlined, size: 14, color: Color(0xFF0F766E)),
                                      SizedBox(width: 4),
                                      Text('Log Site Visit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (daySiteVisits.isNotEmpty) ...[
                              for (int i = 0; i < daySiteVisits.length; i++) ...[
                                _buildSiteVisitDetailItem(daySiteVisits[i], ctx),
                                if (i < daySiteVisits.length - 1) const Divider(height: 16),
                              ],
                            ] else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No site visits logged by this employee on this date.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${monthOffice.length} Days',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const Text('Office Days in Month', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${monthVisits.length} Visits',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const Text('Site Visits in Month', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${totalMonthHours.toStringAsFixed(1)} hrs',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const Text('Total Office Hours', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AllEmployeesAttendanceView.darkSlate,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required String label,
    required String value,
    String? subvalue,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subvalue != null && subvalue.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subvalue,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSiteVisitDetailItem(SiteVisitRecord visit, BuildContext dialogCtx) {
    return InkWell(
      onTap: () {
        Navigator.pop(dialogCtx);
        widget.onOpenSiteVisitDetails?.call(visit);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.location_on, size: 16, color: Color(0xFF0F766E)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        visit.siteName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        visit.visitTime,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                  if (visit.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      visit.address,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (visit.notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Notes: ${visit.notes}',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Employee emp, {double size = 38}) {
    final initials = emp.fullName.trim().isNotEmpty
        ? emp.fullName
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join('')
            .toUpperCase()
        : 'E';

    ImageProvider? imageProvider;
    final imgUrl = emp.profileImageUrl;

    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
        imageProvider = NetworkImage(imgUrl);
      } else if (imgUrl.startsWith('data:image')) {
        try {
          final base64Str = imgUrl.split(',').last.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(base64Str);
          if (bytes.isNotEmpty) imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (imgUrl.length > 50) {
        try {
          final cleaned = imgUrl.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleaned);
          if (bytes.isNotEmpty) imageProvider = MemoryImage(bytes);
        } catch (_) {}
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AllEmployeesAttendanceView.primaryGreen.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider != null
          ? Image(
              image: imageProvider,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.bold,
                    color: AllEmployeesAttendanceView.darkSlate,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.bold,
                  color: AllEmployeesAttendanceView.darkSlate,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _filterEmployees();
    final departments = _extractDepartments();

    int totalOfficePresent = 0;
    int totalSiteVisitsToday = 0;
    int totalSiteEmployees = 0;
    int totalBothOfficeAndSite = 0;
    int totalOnDutyOrLeave = 0;
    int totalAbsent = 0;

    for (final emp in widget.allEmployees) {
      final officeRec = _findOfficeRecord(emp, _selectedDate);
      final siteVisits = _findSiteVisits(emp, _selectedDate);
      final hasOffice = officeRec != null &&
          (officeRec.effectiveCheckInTime.isNotEmpty ||
           officeRec.status.toLowerCase() == 'present' ||
           officeRec.status.toLowerCase() == 'checked out' ||
           officeRec.status.toLowerCase() == 'late');
      final hasSite = siteVisits.isNotEmpty;

      if (hasOffice && hasSite) {
        totalBothOfficeAndSite++;
        totalOfficePresent++;
        totalSiteEmployees++;
        totalSiteVisitsToday += siteVisits.length;
      } else if (hasOffice) {
        totalOfficePresent++;
      } else if (hasSite) {
        totalSiteEmployees++;
        totalSiteVisitsToday += siteVisits.length;
      } else {
        final statusInfo = AttendanceStatusHelper.resolveStatus(
          employee: emp,
          date: _selectedDate,
          record: officeRec,
          leaves: widget.leaves,
          onDutyAssignments: widget.onDutyAssignments,
          holidays: widget.holidays,
          permissions: widget.permissions,
        );
        if (statusInfo == AttendanceStatusInfo.onDuty || statusInfo == AttendanceStatusInfo.onLeave) {
          totalOnDutyOrLeave++;
        } else if (statusInfo == AttendanceStatusInfo.absent) {
          totalAbsent++;
        }
      }
    }

    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final paginatedEmployees = startIndex >= filteredEmployees.length
        ? <Employee>[]
        : filteredEmployees.sublist(
            startIndex,
            (startIndex + _rowsPerPage).clamp(0, filteredEmployees.length),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiSummaryRow(
          totalStaff: widget.allEmployees.length,
          officePresent: totalOfficePresent,
          siteEmployees: totalSiteEmployees,
          siteVisitsCount: totalSiteVisitsToday,
          dualPresence: totalBothOfficeAndSite,
          odOrLeave: totalOnDutyOrLeave,
          absent: totalAbsent,
        ),
        const SizedBox(height: 16),

        _buildControlToolbar(departments),
        const SizedBox(height: 16),

        _buildSectionHeader(filteredEmployees.length),
        const SizedBox(height: 12),

        if (filteredEmployees.isEmpty)
          _buildEmptyState()
        else if (_isTableView)
          _buildTableView(paginatedEmployees)
        else
          _buildCardView(paginatedEmployees),

        const SizedBox(height: 16),

        if (filteredEmployees.isNotEmpty)
          _buildPaginationBar(filteredEmployees.length),
      ],
    );
  }

  Widget _buildKpiSummaryRow({
    required int totalStaff,
    required int officePresent,
    required int siteEmployees,
    required int siteVisitsCount,
    required int dualPresence,
    required int odOrLeave,
    required int absent,
  }) {
    final kpis = [
      _KpiItem('Total Staff', '$totalStaff', 'All registered', Icons.people_outline, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _KpiItem('Office Present', '$officePresent', 'Checked in office', Icons.storefront_outlined, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      _KpiItem('Site Active', '$siteEmployees', '$siteVisitsCount visits logged', Icons.location_on_outlined, const Color(0xFF0D9488), const Color(0xFFF0FDFA)),
      _KpiItem('Both (Office+Site)', '$dualPresence', 'Dual presence', Icons.domain_verification_rounded, AllEmployeesAttendanceView.primaryGreen, const Color(0xFFF7FEE7)),
      _KpiItem('On Duty / Leave', '$odOrLeave', 'Authorized out', Icons.badge_outlined, const Color(0xFFCA8A04), const Color(0xFFFEFCE8)),
      _KpiItem('Absent / Unmarked', '$absent', 'No attendance punch', Icons.cancel_outlined, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
    ];

    if (widget.isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: kpis.length,
        itemBuilder: (_, i) => _buildKpiCard(kpis[i]),
      );
    }

    return Row(
      children: kpis
          .map((kpi) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildKpiCard(kpi),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard(_KpiItem kpi) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kpi.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.iconColor, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.value,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      kpi.label,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            kpi.subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildControlToolbar(List<String> departments) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    tooltip: 'Previous Day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        _currentPage = 1;
                        if (_selectedDate.month != widget.focusedMonth.month ||
                            _selectedDate.year != widget.focusedMonth.year) {
                          widget.onMonthChanged?.call(DateTime(_selectedDate.year, _selectedDate.month, 1));
                        }
                      });
                    },
                  ),
                  InkWell(
                    onTap: _openDatePicker,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                          const Icon(Icons.calendar_today_outlined, size: 15, color: AllEmployeesAttendanceView.darkSlate),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AllEmployeesAttendanceView.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Today',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.darkSlate),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Next Day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                        _currentPage = 1;
                        if (_selectedDate.month != widget.focusedMonth.month ||
                            _selectedDate.year != widget.focusedMonth.year) {
                          widget.onMonthChanged?.call(DateTime(_selectedDate.year, _selectedDate.month, 1));
                        }
                      });
                    },
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(now.year, now.month, now.day);
                          _currentPage = 1;
                          if (now.month != widget.focusedMonth.month || now.year != widget.focusedMonth.year) {
                            widget.onMonthChanged?.call(DateTime(now.year, now.month, 1));
                          }
                        });
                      },
                      child: const Text('Go to Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.darkSlate)),
                    ),
                ],
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Month: ${DateFormat('MMMM yyyy').format(widget.focusedMonth)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search employee by name, ID, department or role...',
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AllEmployeesAttendanceView.primaryGreen),
              ),
            ),
            onChanged: (val) => setState(() {
              _searchQuery = val.trim();
              _currentPage = 1;
            }),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedDepartment,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDepartment = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String>(
                  value: _selectedScheduleType,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  items: ['All Schedules', 'Office (Fixed)', 'Site (Flexible)', 'Hybrid / Dual']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedScheduleType = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),

              _buildFilterChip('All', 'All'),
              _buildFilterChip('Office & Site', 'Office & Site'),
              _buildFilterChip('Office Present', 'Office'),
              _buildFilterChip('Site Active', 'Site'),
              _buildFilterChip('On Duty', 'On Duty'),
              _buildFilterChip('On Leave', 'On Leave'),
              _buildFilterChip('Absent', 'Absent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusFilter = isSelected && value != 'All' ? 'All' : value;
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AllEmployeesAttendanceView.darkSlate : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AllEmployeesAttendanceView.darkSlate : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int filteredCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AllEmployeesAttendanceView.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups_outlined, size: 18, color: AllEmployeesAttendanceView.primaryGreen),
            ),
            const SizedBox(width: 8),
            Text(
              'All Employees Attendance ($filteredCount)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),

        InkWell(
          onTap: () => setState(() => _isTableView = !_isTableView),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_outlined, size: 15, color: const Color(0xFF475569)),
                const SizedBox(width: 5),
                Text(
                  _isTableView ? 'View Cards' : 'View Table',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'No matching employee records found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          SizedBox(height: 4),
          Text(
            'Try adjusting your search query, filters, or selected date.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView(List<Employee> employees) {
    return Column(
      children: [
        for (final emp in employees) ...[
          _buildEmployeeCard(emp),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmployeeCard(Employee emp) {
    final officeRec = _findOfficeRecord(emp, _selectedDate);
    final daySiteVisits = _findSiteVisits(emp, _selectedDate);
    final statusInfo = AttendanceStatusHelper.resolveStatus(
      employee: emp,
      date: _selectedDate,
      record: officeRec,
      leaves: widget.leaves,
      onDutyAssignments: widget.onDutyAssignments,
      holidays: widget.holidays,
      permissions: widget.permissions,
    );
    final unifiedStatus = _resolveUnifiedStatus(
      employee: emp,
      officeRecord: officeRec,
      daySiteVisits: daySiteVisits,
      statusInfo: statusInfo,
      date: _selectedDate,
    );

    final isFixed = emp.isStaticEmployee || emp.workScheduleType.trim().toLowerCase() == 'fixed schedule';
    final isFlexible = emp.isDynamicEmployee || emp.workScheduleType.trim().toLowerCase() == 'flexible schedule';
    final scheduleLabel = isFixed && !isFlexible
        ? 'Office Schedule'
        : (!isFixed && isFlexible ? 'Field / Site' : 'Hybrid');

    final monthOffice = _getMonthlyOfficeRecords(emp);
    final monthVisits = _getMonthlySiteVisits(emp);
    double totalMonthHours = 0.0;
    for (final r in monthOffice) {
      totalMonthHours += r.totalHours;
    }

    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildAvatar(emp, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.fullName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${emp.department} • ${emp.designation} • $scheduleLabel',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(unifiedStatus),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusTextColor(unifiedStatus).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(unifiedStatus), size: 14, color: _getStatusTextColor(unifiedStatus)),
                      const SizedBox(width: 5),
                      Text(
                        unifiedStatus,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(unifiedStatus),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Padding(
            padding: const EdgeInsets.all(12),
            child: widget.isMobile
                ? Column(
                    children: [
                      _buildOfficePanel(emp, officeRec, statusInfo),
                      const SizedBox(height: 10),
                      _buildSiteVisitsPanel(emp, daySiteVisits),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildOfficePanel(emp, officeRec, statusInfo)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSiteVisitsPanel(emp, daySiteVisits)),
                    ],
                  ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '🏢 ${monthOffice.length} Office Days',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        '📍 ${monthVisits.length} Site Visits',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        '⏱️ ${totalMonthHours.toStringAsFixed(1)} Total Hrs',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openUnifiedDetailsDialog(emp),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: AllEmployeesAttendanceView.darkSlate),
                  label: const Text('View Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.darkSlate)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficePanel(Employee emp, AttendanceRecord? record, AttendanceStatusInfo? statusInfo) {
    final hasPunch = record != null && record.effectiveCheckInTime.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 16, color: AllEmployeesAttendanceView.darkSlate),
                  SizedBox(width: 6),
                  Text(
                    'Office Attendance',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              if (record != null)
                InkWell(
                  onTap: () => widget.onOpenOfficeDetails?.call(emp, _selectedDate, record, statusInfo),
                  child: const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.darkSlate)),
                )
              else
                InkWell(
                  onTap: () => widget.onAddOfficeEntry?.call(null, emp.id, DateFormat('dd-MM-yyyy').format(_selectedDate)),
                  child: const Text('+ Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AllEmployeesAttendanceView.primaryGreen)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (hasPunch) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('In', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text(
                        record.formattedCheckInTime,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Out', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text(
                        record.checkOutTime.isNotEmpty ? record.formattedCheckOutTime : 'In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: record.checkOutTime.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Work Hours', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text(
                        record.totalHours > 0 ? '${record.totalHours.toStringAsFixed(1)} hrs' : '--',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (record.effectiveCheckInVerification.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 12, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.effectiveCheckInVerification,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No office check-in marked for this date.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteVisitsPanel(Employee emp, List<SiteVisitRecord> visits) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Text(
                    'Site Visits (${visits.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onAddSiteEntry?.call(null),
                child: const Text('+ Visit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (visits.isNotEmpty) ...[
            for (final v in visits.take(2))
              InkWell(
                onTap: () => widget.onOpenSiteVisitDetails?.call(v),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.siteName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${v.visitTime} ${v.address.isNotEmpty ? '• ${v.address}' : ''}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            if (visits.length > 2)
              Text(
                '+ ${visits.length - 2} more visit(s)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No site visits recorded for this date.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableView(List<Employee> employees) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            dataRowMinHeight: 60,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Daily Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Office Attendance', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Site Visits', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Month Totals', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
            ],
            rows: employees.map((emp) {
              final officeRec = _findOfficeRecord(emp, _selectedDate);
              final daySiteVisits = _findSiteVisits(emp, _selectedDate);
              final statusInfo = AttendanceStatusHelper.resolveStatus(
                employee: emp,
                date: _selectedDate,
                record: officeRec,
                leaves: widget.leaves,
                onDutyAssignments: widget.onDutyAssignments,
                holidays: widget.holidays,
                permissions: widget.permissions,
              );
              final unifiedStatus = _resolveUnifiedStatus(
                employee: emp,
                officeRecord: officeRec,
                daySiteVisits: daySiteVisits,
                statusInfo: statusInfo,
                date: _selectedDate,
              );

              final isFixed = emp.isStaticEmployee || emp.workScheduleType.trim().toLowerCase() == 'fixed schedule';
              final isFlexible = emp.isDynamicEmployee || emp.workScheduleType.trim().toLowerCase() == 'flexible schedule';
              final scheduleLabel = isFixed && !isFlexible
                  ? 'Office (Fixed)'
                  : (!isFixed && isFlexible ? 'Site (Flexible)' : 'Hybrid');

              final monthOffice = _getMonthlyOfficeRecords(emp);
              final monthVisits = _getMonthlySiteVisits(emp);

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        _buildAvatar(emp, size: 34),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                            Text(
                              '${emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id}'} • ${emp.department}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  DataCell(
                    Text(scheduleLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ),

                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(unifiedStatus),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(unifiedStatus), size: 12, color: _getStatusTextColor(unifiedStatus)),
                          const SizedBox(width: 4),
                          Text(
                            unifiedStatus,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusTextColor(unifiedStatus)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  DataCell(
                    officeRec != null && officeRec.effectiveCheckInTime.isNotEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${officeRec.formattedCheckInTime} – ${officeRec.checkOutTime.isNotEmpty ? officeRec.formattedCheckOutTime : 'Active'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                '${officeRec.totalHours > 0 ? '${officeRec.totalHours.toStringAsFixed(1)} hrs' : ''} ${officeRec.status}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A)),
                              ),
                            ],
                          )
                        : const Text('--', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),

                  DataCell(
                    daySiteVisits.isNotEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${daySiteVisits.length} Visit(s)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                              ),
                              Text(
                                daySiteVisits.map((v) => v.siteName).take(2).join(', '),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : const Text('--', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),

                  DataCell(
                    Text(
                      '${monthOffice.length} Office / ${monthVisits.length} Sites',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),

                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AllEmployeesAttendanceView.darkSlate),
                          tooltip: 'View Details',
                          onPressed: () => _openUnifiedDetailsDialog(emp),
                        ),
                        if (officeRec != null)
                          IconButton(
                            icon: const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF16A34A)),
                            tooltip: 'Office Record',
                            onPressed: () => widget.onOpenOfficeDetails?.call(emp, _selectedDate, officeRec, statusInfo),
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

  Widget _buildPaginationBar(int totalItems) {
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
      child: widget.isMobile
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
}

class _KpiItem {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  _KpiItem(this.label, this.value, this.subtitle, this.icon, this.iconColor, this.bgColor);
}
