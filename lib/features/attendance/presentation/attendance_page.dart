import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/attendance_record.dart';
import '../../employee/domain/employee.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/domain/leave_type.dart';
import '../../leave/domain/leave_balance.dart';
import '../../leave/providers/leave_providers.dart';
import '../../leave/presentation/my_leave_requests_page.dart';
import '../domain/attendance_repository.dart';
import '../../permission/domain/permission_enums.dart';
import '../../permission/domain/permission_request.dart';
import '../../permission/providers/permission_providers.dart';
import '../providers/attendance_providers.dart';
import '../../time_clocking/presentation/employee_clocking_widget.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  int _currentTabIndex = 0;
  DateTime _focusedMonth = DateTime.now();

  // Leave List Filter State
  String _statusFilter = 'All';
  String _requestTypeFilter = 'All';
  String _leaveTypeFilter = 'All';
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  int get _activeFilterCount {
    int count = 0;
    if (_statusFilter != 'All') count++;
    if (_requestTypeFilter != 'All') count++;
    if (_leaveTypeFilter != 'All') count++;
    if (_filterFromDate != null || _filterToDate != null) count++;
    return count;
  }

  List<LeaveRequest> _getFilteredRequests(List<LeaveRequest> requests) {
    return requests.where((req) {
      if (_statusFilter != 'All' && req.status.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      final isPerm = req.leaveType.toLowerCase().startsWith('permission');
      if (_requestTypeFilter == 'Leave' && isPerm) return false;
      if (_requestTypeFilter == 'Permission' && !isPerm) return false;

      if (_leaveTypeFilter != 'All' && req.leaveType != _leaveTypeFilter) {
        return false;
      }

      if (_filterFromDate != null || _filterToDate != null) {
        final reqFrom = _parseKey(req.fromDate);
        final reqTo = _parseKey(req.toDate) ?? reqFrom;
        if (reqFrom != null && reqTo != null) {
          if (_filterFromDate != null && reqTo.isBefore(_filterFromDate!)) {
            return false;
          }
          if (_filterToDate != null && reqFrom.isAfter(_filterToDate!.add(const Duration(days: 1)))) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  // Apply Leave Form State
  String _selectedLeaveType = 'Casual Leave';
  DateTime? _fromDate = DateTime.now();
  DateTime? _toDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _cancelRequest(LeaveRequest req, Employee currentEmp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this pending leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, keep it', style: TextStyle(color: Color(0xFF414A51))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(leaveRepositoryProvider).cancelLeaveRequest(req.id, currentEmp.fullName);
        ref.invalidate(leaveRequestsProvider(currentEmp.id));
        ref.invalidate(allLeaveRequestsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request cancelled successfully'),
              backgroundColor: Color(0xFF414A51),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling request: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    }
  }

  String _formatKey(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  DateTime? _parseKey(String value) {
    if (value.isEmpty) return null;
    try {
      final isoDate = DateTime.tryParse(value);
      if (isoDate != null) return isoDate;

      final parts = value.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'present':
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'pending':
      case 'late':
      case 'insufficient hours':
      case 'insufficient':
        return const Color(0xFFE65100);
      case 'denied':
      case 'rejected':
      case 'absent':
        return const Color(0xFFC62828);
      case 'leave':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF414A51);
    }
  }

  String _formatDateStr(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final isoDate = DateTime.tryParse(dateStr);
      if (isoDate != null) {
        return DateFormat('dd MMM yyyy').format(isoDate);
      }
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return DateFormat('dd MMM yyyy').format(d);
        } else {
          final d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          return DateFormat('dd MMM yyyy').format(d);
        }
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: Text('No employee profile found.')),
      );
    }

    final attendanceAsync = ref.watch(attendanceRecordsProvider(currentEmp.id));
    final todayAttendanceAsync = ref.watch(todayAttendanceRecordProvider(currentEmp.id));
    final leaveAsync = ref.watch(attendanceLeaveRequestsProvider(currentEmp.id));
    final userLeaveRequestsAsync = ref.watch(leaveRequestsProvider(currentEmp.id));

    final activeTab = ref.watch(attendanceActiveTabProvider);
    _currentTabIndex = activeTab;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        bottom: true,
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // Tab 0: Home Overview Tab
            _buildHomeTab(currentEmp, todayAttendanceAsync, attendanceAsync, leaveAsync),
            // Tab 1: Monthly Calendar Tab
            _buildCalendarTab(currentEmp, attendanceAsync, leaveAsync),
            // Tab 2: Leave Dashboard Tab
            _buildLeaveTab(currentEmp, userLeaveRequestsAsync),
            // Tab 3: Salary & LOP Tab
            _buildSalaryLopTab(currentEmp, userLeaveRequestsAsync),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            ref.read(attendanceActiveTabProvider.notifier).state = index;
            setState(() {
              _currentTabIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF9CC70A),
          unselectedItemColor: const Color(0xFF94A3B8),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Leave',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Salary & LOP',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: HOME OVERVIEW TAB
  // ==========================================
  Widget _buildHomeTab(
    Employee currentEmp,
    AsyncValue<AttendanceRecord?> todayAttendanceAsync,
    AsyncValue<List<AttendanceRecord>> attendanceAsync,
    AsyncValue<List<LeaveRequest>> leaveAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's Status Banner Card
          _buildTodayBannerCard(currentEmp, todayAttendanceAsync),
          const SizedBox(height: 20),

          // Work Activity / Clocking Section
          EmployeeClockingWidget(employeeId: currentEmp.employeeId.isNotEmpty ? currentEmp.employeeId : currentEmp.id.toString()),
          const SizedBox(height: 24),

          // This Month Overview Card
          attendanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (records) => leaveAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (leaves) => _buildMonthOverviewCard(records, leaves.cast<LeaveRequest>()),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Records Header & List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Records',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(attendanceActiveTabProvider.notifier).state = 1;
                  setState(() {
                    _currentTabIndex = 1; // Switch to Calendar
                  });
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recent Records List
          attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (records) => _buildRecentRecordsList(records),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthOverviewCard(List<AttendanceRecord> records, List<LeaveRequest> leaves) {
    final now = DateTime.now();
    final currentMonthRecords = records.where((r) {
      final parsed = _parseKey(r.date);
      return parsed != null && parsed.month == now.month && parsed.year == now.year;
    }).toList();

    final presentCount = currentMonthRecords.where((r) => r.status == 'Present' || r.status == 'Checked Out' || r.status == 'Completed').length;
    final absentCount = currentMonthRecords.where((r) => r.status == 'Absent').length;
    final leaveCount = leaves.where((l) => l.status == 'Approved').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Month Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$presentCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Present',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$absentCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Absent',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$leaveCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Leave',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecordsList(List<AttendanceRecord> records) {
    final sorted = List<AttendanceRecord>.from(records);
    sorted.sort((a, b) {
      final da = _parseKey(a.date) ?? DateTime(2000);
      final db = _parseKey(b.date) ?? DateTime(2000);
      return db.compareTo(da);
    });

    final recentList = sorted.take(5).toList();

    if (recentList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No attendance records found.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return Column(
      children: recentList.map((rec) {
        final dt = _parseKey(rec.date);
        final dateFormatted = dt != null ? DateFormat('dd MMM yyyy').format(dt) : rec.date;
        final dayName = dt != null ? DateFormat('EEEE').format(dt) : '';
        final isPresent = rec.status == 'Present' || rec.status == 'Checked Out' || rec.status == 'Completed';
        final statusColor = isPresent
            ? const Color(0xFF2E7D32)
            : rec.status == 'Late'
                ? const Color(0xFFE65100)
                : const Color(0xFFC62828);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormatted,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    if (dayName.isNotEmpty)
                      Text(
                        dayName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rec.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  if (rec.effectiveCheckInTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Check-in: ${rec.effectiveCheckInTime}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // TAB 1: CALENDAR TAB
  // ==========================================
  // ==========================================
  // TAB 1: CALENDAR TAB
  // ==========================================
  Widget _buildCalendarTab(
    Employee currentEmp,
    AsyncValue<List<AttendanceRecord>> attendanceAsync,
    AsyncValue<List<LeaveRequest>> leaveAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly Calendar Section
          attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
            error: (e, _) => Text('Error loading attendance: $e'),
            data: (attendanceRecords) => leaveAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
              error: (e, _) => Text('Error loading leaves: $e'),
              data: (leaveRequests) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCalendar(
                    attendanceRecords,
                    leaveRequests.cast<LeaveRequest>(),
                  ),
                  const SizedBox(height: 20),
                  _buildMonthlyAttendanceHistory(
                    attendanceRecords,
                    leaveRequests.cast<LeaveRequest>(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAttendanceHistory(
    List<AttendanceRecord> records,
    List<LeaveRequest> leaveRequests,
  ) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();

    final Map<String, AttendanceRecord> attMap = {};
    for (final r in records) {
      final dt = _parseKey(r.date);
      if (dt != null) {
        final key = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        attMap[key] = r;
      }
    }

    final Map<String, LeaveRequest> leaveMap = {};
    for (final l in leaveRequests) {
      final from = _parseKey(l.fromDate);
      final to = _parseKey(l.toDate) ?? from;
      if (from != null && to != null) {
        var curr = from;
        while (!curr.isAfter(to)) {
          final key = '${curr.day.toString().padLeft(2, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.year}';
          leaveMap[key] = l;
          curr = curr.add(const Duration(days: 1));
        }
      }
    }

    int presentCount = 0;
    int lateCount = 0;
    int leaveCount = 0;
    int absentCount = 0;

    List<_DailyHistoryItem> items = [];

    final lastDayToDisplay = (year == now.year && month == now.month) ? math.min(now.day, daysInMonth) : daysInMonth;

    for (int day = lastDayToDisplay; day >= 1; day--) {
      final dt = DateTime(year, month, day);
      final key = '${day.toString().padLeft(2, '0')}-${month.toString().padLeft(2, '0')}-${year}';
      final isSunday = dt.weekday == DateTime.sunday;

      final att = attMap[key];
      final leave = leaveMap[key];

      String status = 'Absent';
      String checkIn = '';
      String checkOut = '';
      String duration = '';
      String note = '';

      if (att != null) {
        status = att.status.isNotEmpty ? att.status : 'Present';
        checkIn = att.effectiveCheckInTime;
        checkOut = att.checkOutTime;
        if (att.totalHours > 0) {
          duration = '${att.totalHours} hrs';
        }
        note = att.notes;
      } else if (leave != null) {
        status = leave.status.toLowerCase() == 'approved' || leave.status.toLowerCase() == 'pending' ? 'Leave' : 'Denied';
        duration = _formatDurationDisplay(leave);
        note = 'Reason: ${leave.reason}';
      } else if (isSunday) {
        status = 'Week Off';
      }

      final stLower = status.toLowerCase();
      if (stLower == 'present' || stLower == 'completed' || stLower == 'checked out') presentCount++;
      else if (stLower == 'late' || stLower == 'insufficient hours' || stLower == 'insufficient') lateCount++;
      else if (stLower == 'leave') leaveCount++;
      else if (stLower == 'absent') absentCount++;

      items.add(_DailyHistoryItem(
        date: dt,
        status: status,
        checkIn: checkIn,
        checkOut: checkOut,
        duration: duration,
        note: note,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Attendance History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMiniStatTile('Present', '$presentCount', const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            _buildMiniStatTile('Late', '$lateCount', const Color(0xFFE65100)),
            const SizedBox(width: 8),
            _buildMiniStatTile('Leave', '$leaveCount', const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            _buildMiniStatTile('Absent', '$absentCount', const Color(0xFFC62828)),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No attendance history for this month.', style: TextStyle(color: Color(0xFF64748B))),
            ),
          )
        else
          Column(
            children: items.map((item) => _buildHistoryCard(item)).toList(),
          ),
      ],
    );
  }

  Widget _buildHistoryCard(_DailyHistoryItem item) {
    final statusColor = _getStatusColor(item.status);
    final dateStr = DateFormat('dd MMM yyyy (EEEE)').format(item.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          if (item.checkIn.isNotEmpty || item.checkOut.isNotEmpty || item.duration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.checkIn.isNotEmpty
                      ? 'In: ${item.checkIn}${item.checkOut.isNotEmpty ? '  |  Out: ${item.checkOut}' : ''}'
                      : (item.duration.isNotEmpty ? item.duration : ''),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                if (item.duration.isNotEmpty && item.checkIn.isNotEmpty)
                  Text(
                    item.duration,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
              ],
            ),
          ],
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.note,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStatTile(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetailCard(AsyncValue<List<AttendanceRecord>> attendanceAsync) {
    final todayStr = DateFormat('dd MMMM yyyy, Today').format(DateTime.now());
    final todayKey = _formatKey(DateTime.now());

    return attendanceAsync.maybeWhen(
      data: (records) {
        final rec = records.where((r) => r.date == todayKey).firstOrNull;
        final hasCheckIn = rec != null && rec.effectiveCheckInTime.isNotEmpty;
        final hasCheckOut = rec != null && rec.checkOutTime.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayStr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasCheckIn ? const Color(0xFF2E7D32) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasCheckIn ? 'Checked In' : 'Not Marked',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: hasCheckIn ? const Color(0xFF2E7D32) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    hasCheckIn ? rec!.effectiveCheckInTime : '--:--',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Working Hours',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  Text(
                    hasCheckOut && rec != null && rec.totalHours > 0
                        ? '${rec.totalHours} hrs'
                        : '-- : --',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ==========================================
  // TAB 2: LEAVE TAB (Matching Image 2 design)
  // ==========================================
  Widget _buildLeaveTab(Employee currentEmp, AsyncValue<List<LeaveRequest>> userLeaveRequestsAsync) {
    return userLeaveRequestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
      error: (e, _) => Center(child: Text('Error loading leave requests: $e')),
      data: (requests) {
        final leaveOnlyRequests = requests
            .where((r) => !r.leaveType.toLowerCase().startsWith('permission'))
            .toList();
        final filteredRequests = _getFilteredRequests(leaveOnlyRequests);
        final now = DateTime.now();
        final thisMonthRequests = leaveOnlyRequests.where((r) {
          final from = _parseKey(r.fromDate);
          final to = _parseKey(r.toDate) ?? from;
          if (from == null && to == null) return false;
          final start = DateTime(now.year, now.month, 1);
          final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          return (from != null && !from.isBefore(start) && !from.isAfter(end)) ||
                 (to != null && !to.isBefore(start) && !to.isAfter(end));
        }).toList();

        final totalRequests = thisMonthRequests.length;
        final pendingCount = thisMonthRequests.where((r) => r.status.toLowerCase() == 'pending').length;
        final approvedCount = thisMonthRequests.where((r) => r.status.toLowerCase() == 'approved').length;
        final deniedCount = thisMonthRequests.where((r) => r.status.toLowerCase() == 'denied' || r.status.toLowerCase() == 'rejected').length;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Summary Stat Cards Grid (This Month Details)
                  Row(
                    children: [
                      Expanded(
                        child: _buildLeaveStatCard(
                          'Total Requests',
                          '$totalRequests',
                          Icons.folder_outlined,
                          const Color(0xFF0288D1),
                          const Color(0xFFE1F5FE),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLeaveStatCard(
                          'Pending Requests',
                          '$pendingCount',
                          Icons.hourglass_top_outlined,
                          const Color(0xFFE65100),
                          const Color(0xFFFFF3E0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLeaveStatCard(
                          'Approved Leaves',
                          '$approvedCount',
                          Icons.check_circle_outline,
                          const Color(0xFF2E7D32),
                          const Color(0xFFE8F5E9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLeaveStatCard(
                          'Denied Requests',
                          '$deniedCount',
                          Icons.cancel_outlined,
                          const Color(0xFFC62828),
                          const Color(0xFFFFEBEE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Header + My Requests Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Requests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF414A51),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (context) => MyLeaveRequestsPage(currentEmp: currentEmp),
                          ),
                        ),
                        icon: const Icon(Icons.list_alt, size: 16, color: Color(0xFF414A51)),
                        label: const Text(
                          'My Requests',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Action Bar: [ All Status ▼ ]  [ 📅 Date ]  [ ⚙ Filters ]
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Quick Status Dropdown Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusFilter,
                              isDense: true,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                              items: ['All', 'Pending', 'Approved', 'Denied', 'Cancelled']
                                  .map((st) => DropdownMenuItem(value: st, child: Text(st == 'All' ? 'All Status' : st)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _statusFilter = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Date Filter Pill Button
                        InkWell(
                          onTap: () => _showDateFilterBottomSheet(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_filterFromDate != null || _filterToDate != null)
                                  ? const Color(0xFF9CC70A).withValues(alpha: 0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (_filterFromDate != null || _filterToDate != null)
                                    ? const Color(0xFF9CC70A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _filterFromDate != null && _filterToDate != null
                                      ? '${DateFormat('dd MMM').format(_filterFromDate!)} – ${DateFormat('dd MMM').format(_filterToDate!)} 📅'
                                      : '📅 Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: (_filterFromDate != null || _filterToDate != null)
                                        ? const Color(0xFF414A51)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Advanced Filters Button
                        InkWell(
                          onTap: () => _showAdvancedFiltersBottomSheet(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeFilterCount > 0
                                  ? const Color(0xFF414A51)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activeFilterCount > 0 ? const Color(0xFF414A51) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 16,
                                  color: _activeFilterCount > 0 ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Filters',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _activeFilterCount > 0 ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                                if (_activeFilterCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF9CC70A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_activeFilterCount',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "Showing X requests" count label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${filteredRequests.length} request${filteredRequests.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      if (_activeFilterCount > 0)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _statusFilter = 'All';
                              _requestTypeFilter = 'All';
                              _leaveTypeFilter = 'All';
                              _filterFromDate = null;
                              _filterToDate = null;
                            });
                          },
                          child: const Text(
                            'Reset Filters',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filtered Recent Leave Requests List
                  if (filteredRequests.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'No leave requests found matching selected filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          if (_activeFilterCount > 0) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'All';
                                  _requestTypeFilter = 'All';
                                  _leaveTypeFilter = 'All';
                                  _filterFromDate = null;
                                  _filterToDate = null;
                                });
                              },
                              child: const Text(
                                'Reset All Filters',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Column(
                      children: filteredRequests.map((req) => _buildLeaveActivityCard(req, currentEmp)).toList(),
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'apply_leave_fab',
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onPressed: () => _showApplyLeaveDialog(currentEmp),
                child: const Icon(Icons.add, size: 26),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaveStatCard(String title, String value, IconData icon, Color iconColor, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveActivityCard(LeaveRequest req, Employee currentEmp) {
    final statusColor = _getStatusColor(req.status);
    final isPermission = req.leaveType.toLowerCase().startsWith('permission');
    final isPending = req.status.toLowerCase() == 'pending';

    String tagText = 'LEAVE';
    Color tagBg = const Color(0xFFF0FDF4);
    Color tagColor = const Color(0xFF15803D);
    Color iconBg = const Color(0xFFDCFCE7);
    Color iconColor = const Color(0xFF16A34A);
    IconData leadingIcon = Icons.access_time_filled;

    if (isPermission) {
      tagText = 'PERMISSION';
      tagBg = const Color(0xFFEFF6FF);
      tagColor = const Color(0xFF1D4ED8);
      iconBg = const Color(0xFFDBEAFE);
      iconColor = const Color(0xFF2563EB);
      leadingIcon = Icons.access_time_filled;
    } else {
      final typeLower = req.leaveType.toLowerCase();
      if (typeLower.contains('casual')) {
        tagText = 'CASUAL LEAVE';
        tagBg = const Color(0xFFF0FDF4);
        tagColor = const Color(0xFF15803D);
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        leadingIcon = Icons.access_time_filled;
      } else if (typeLower.contains('annual')) {
        tagText = 'ANNUAL LEAVE';
        tagBg = const Color(0xFFFFF7ED);
        tagColor = const Color(0xFFC2410C);
        iconBg = const Color(0xFFFFEDD5);
        iconColor = const Color(0xFFEA580C);
        leadingIcon = Icons.access_time_filled;
      } else if (typeLower.contains('sick')) {
        tagText = 'SICK LEAVE';
        tagBg = const Color(0xFFFEF2F2);
        tagColor = const Color(0xFFB91C1C);
        iconBg = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        leadingIcon = Icons.access_time_filled;
      } else {
        tagText = req.leaveType.toUpperCase();
        tagBg = const Color(0xFFF8FAFC);
        tagColor = const Color(0xFF475569);
        iconBg = const Color(0xFFF1F5F9);
        iconColor = const Color(0xFF64748B);
        leadingIcon = Icons.access_time_filled;
      }
    }

    String cardTitle = req.leaveType;
    if (!isPermission) {
      cardTitle = '${req.leaveType} (${_formatDurationDisplay(req)})';
    }

    String dateDisplay = _formatDateStr(req.fromDate);
    if (req.fromDate != req.toDate && req.toDate.isNotEmpty) {
      dateDisplay = '${_formatDateStr(req.fromDate)} - ${_formatDateStr(req.toDate)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tagText,
                  style: TextStyle(
                    color: tagColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Color(0xFF94A3B8), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'view') {
                    _showViewLeaveDialog(req);
                  } else if (val == 'edit' && isPending) {
                    _showApplyLeaveDialog(currentEmp, existingRequest: req);
                  } else if (val == 'cancel' && isPending) {
                    _cancelRequest(req, currentEmp);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('View Details', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (isPending) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFFE65100)),
                          SizedBox(width: 8),
                          Text('Edit Request', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFC62828)),
                          SizedBox(width: 8),
                          Text('Cancel Request', style: TextStyle(fontSize: 13, color: Color(0xFFC62828))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cardTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                dateDisplay,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (req.reason.isNotEmpty) ...[
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                children: [
                  const TextSpan(text: 'Reason: ', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
                  TextSpan(text: req.reason, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Submitted on ${_formatDateStr(req.createdAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF65A30D),
                  side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _showViewLeaveDialog(req),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 15, color: Color(0xFF65A30D)),
                label: const Text(
                  'View Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF65A30D)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDurationDisplay(LeaveRequest req) {
    if (req.leaveType.toLowerCase().startsWith('permission')) {
      if (req.leaveType.contains('(') && req.leaveType.contains(')')) {
        final timePart = req.leaveType.substring(req.leaveType.indexOf('(') + 1, req.leaveType.indexOf(')'));
        return 'Permission ($timePart)';
      }
      final hours = req.numDays * 8.0;
      if (hours > 0) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        if (h > 0 && m > 0) return '$h Hr $m Mins';
        if (h > 0) return '$h Hour${h > 1 ? 's' : ''}';
        return '$m Mins';
      }
      return 'Permission';
    }
    final isWhole = (req.numDays == req.numDays.roundToDouble());
    final daysStr = isWhole ? req.numDays.toInt().toString() : req.numDays.toStringAsFixed(1);
    return '$daysStr Day${req.numDays == 1.0 ? '' : 's'}';
  }

  // --- DATE FILTER BOTTOM SHEET ---
  void _showDateFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final now = DateTime.now();

            void setQuickDate(DateTime from, DateTime to) {
              setSheetState(() {
                _filterFromDate = from;
                _filterToDate = to;
              });
              setState(() {});
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter by Date',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Quick Select', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => setQuickDate(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
                          child: const Text('This Month', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.w600)),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => setQuickDate(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0)),
                          child: const Text('Last Month', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.w600)),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => setQuickDate(DateTime(now.year, now.month - 3, now.day), now),
                          child: const Text('Last 3 Months', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.w600)),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => setQuickDate(DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
                          child: const Text('This Year', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterFromDate ?? now,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => _filterFromDate = picked);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _filterFromDate != null ? DateFormat('dd MMM yyyy').format(_filterFromDate!) : 'Select Date',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
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
                              const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterToDate ?? now,
                                    firstDate: _filterFromDate ?? DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => _filterToDate = picked);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _filterToDate != null ? DateFormat('dd MMM yyyy').format(_filterToDate!) : 'Select Date',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _filterFromDate = null;
                                _filterToDate = null;
                              });
                              setState(() {});
                            },
                            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9CC70A),
                              foregroundColor: const Color(0xFF414A51),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(sheetCtx);
                            },
                            child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    );
  }

  // --- ADVANCED FILTERS BOTTOM SHEET ---
  void _showAdvancedFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final now = DateTime.now();

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filters',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['All', 'Pending', 'Approved', 'Denied', 'Cancelled'].map((st) {
                        final selected = _statusFilter == st;
                        return ChoiceChip(
                          label: Text(st),
                          selected: selected,
                          selectedColor: const Color(0xFF9CC70A).withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: selected ? const Color(0xFF414A51) : const Color(0xFF64748B),
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            setSheetState(() => _statusFilter = st);
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Request Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['All', 'Leave', 'Permission'].map((rt) {
                        final selected = _requestTypeFilter == rt;
                        return ChoiceChip(
                          label: Text(rt),
                          selected: selected,
                          selectedColor: const Color(0xFF9CC70A).withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: selected ? const Color(0xFF414A51) : const Color(0xFF64748B),
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            setSheetState(() => _requestTypeFilter = rt);
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _leaveTypeFilter,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                        ),
                      ),
                      items: [
                        'All',
                        'Sick Leave',
                        'Casual Leave',
                        'Annual Leave',
                        'Optional Leave',
                        'Emergency Leave',
                        'Work From Home',
                        'Comp Off',
                      ]
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _leaveTypeFilter = val);
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterFromDate ?? now,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => _filterFromDate = picked);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _filterFromDate != null ? DateFormat('dd MMM yyyy').format(_filterFromDate!) : 'Select Date',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
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
                              const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterToDate ?? now,
                                    firstDate: _filterFromDate ?? DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => _filterToDate = picked);
                                    setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _filterToDate != null ? DateFormat('dd MMM yyyy').format(_filterToDate!) : 'Select Date',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                      ),
                                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _statusFilter = 'All';
                                _requestTypeFilter = 'All';
                                _leaveTypeFilter = 'All';
                                _filterFromDate = null;
                                _filterToDate = null;
                              });
                              setState(() {});
                            },
                            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9CC70A),
                              foregroundColor: const Color(0xFF414A51),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(sheetCtx);
                            },
                            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    );
  }

  // --- MY REQUESTS MONTH-WISE & STATUS-WISE DIALOG ---
  void _showMyRequestsMonthWiseDialog(Employee currentEmp, List<LeaveRequest> allRequests) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
        String monthStatus = 'All';

        bool isInMonth(LeaveRequest req, DateTime month) {
          final from = _parseKey(req.fromDate);
          final to = _parseKey(req.toDate) ?? from;
          if (from == null && to == null) return false;

          final start = DateTime(month.year, month.month, 1);
          final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

          if (from != null && from.isAfter(start.subtract(const Duration(seconds: 1))) && from.isBefore(end.add(const Duration(seconds: 1)))) {
            return true;
          }
          if (to != null && to.isAfter(start.subtract(const Duration(seconds: 1))) && to.isBefore(end.add(const Duration(seconds: 1)))) {
            return true;
          }
          return false;
        }

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final monthRequests = allRequests.where((r) => isInMonth(r, selectedMonth)).toList();

            final totalInMonth = monthRequests.length;
            final pendingInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'pending').length;
            final approvedInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'approved').length;
            final deniedInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'denied' || r.status.toLowerCase() == 'rejected').length;
            final cancelledInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'cancelled').length;

            final filteredMonthRequests = monthRequests.where((r) {
              if (monthStatus != 'All' && r.status.toLowerCase() != monthStatus.toLowerCase()) {
                return false;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(sheetCtx).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
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
                              color: const Color(0xFF9CC70A).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.list_alt, size: 20, color: Color(0xFF414A51)),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'My Requests',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Month Navigation Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFF414A51)),
                          onPressed: () {
                            setSheetState(() {
                              selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                            });
                          },
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedMonth,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                selectedMonth = DateTime(picked.year, picked.month, 1);
                              });
                            }
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 18, color: Color(0xFF9CC70A)),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMMM yyyy').format(selectedMonth),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFF414A51)),
                          onPressed: () {
                            setSheetState(() {
                              selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Monthly Stat Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text('$totalInMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0288D1))),
                              const Text('Total', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text('$pendingInMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
                              const Text('Pending', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text('$approvedInMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                              const Text('Approved', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Text('${deniedInMonth + cancelledInMonth}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC62828))),
                              const Text('Denied', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statusChip('All ($totalInMonth)', 'All', monthStatus, (val) => setSheetState(() => monthStatus = val)),
                        const SizedBox(width: 6),
                        _statusChip('Pending ($pendingInMonth)', 'Pending', monthStatus, (val) => setSheetState(() => monthStatus = val)),
                        const SizedBox(width: 6),
                        _statusChip('Approved ($approvedInMonth)', 'Approved', monthStatus, (val) => setSheetState(() => monthStatus = val)),
                        const SizedBox(width: 6),
                        _statusChip('Denied ($deniedInMonth)', 'Denied', monthStatus, (val) => setSheetState(() => monthStatus = val)),
                        const SizedBox(width: 6),
                        _statusChip('Cancelled ($cancelledInMonth)', 'Cancelled', monthStatus, (val) => setSheetState(() => monthStatus = val)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // List of filtered requests in month
                  Expanded(
                    child: filteredMonthRequests.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                Text(
                                  'No requests found for ${DateFormat('MMMM yyyy').format(selectedMonth)}.',
                                  style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredMonthRequests.length,
                            itemBuilder: (context, index) {
                              final req = filteredMonthRequests[index];
                              return _buildLeaveActivityCard(req, currentEmp);
                            },
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

  Widget _statusChip(String label, String value, String currentValue, ValueChanged<String> onSelect) {
    final selected = currentValue.toLowerCase() == value.toLowerCase();
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF9CC70A).withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF414A51) : const Color(0xFF64748B),
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  void _showViewLeaveDialog(LeaveRequest req) {
    final statusColor = _getStatusColor(req.status);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  req.leaveType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Submitted On', _formatDateStr(req.createdAt)),
                  const SizedBox(height: 12),
                  _detailRow('Date Range', '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}'),
                  const SizedBox(height: 12),
                  _detailRow('Duration', _formatDurationDisplay(req)),
                  const SizedBox(height: 12),
                  _detailRow('Reason', req.reason.isNotEmpty ? req.reason : 'N/A'),
                  if (req.approvedBy != null && req.approvedBy!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Approved By', req.approvedBy!),
                  ],
                  if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Rejection Reason', req.rejectionReason!),
                  ],
                  if (req.overrideReason != null && req.overrideReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Override Note', req.overrideReason!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  // --- APPLY LEAVE DIALOG ---
  Future<void> _showApplyLeaveDialog(Employee currentEmp, {LeaveRequest? existingRequest}) async {
    final permissionAllowance = await ref
        .read(leaveRepositoryProvider)
        .getPermissionAllowance(currentEmp.id, DateTime.now());
    if (!mounted) return;
    final allLeaveTypes = ref.read(leaveTypesProvider).value ?? [];
    final activeLeaveTypes = allLeaveTypes.where((t) => t.isActive).toList();

    String requestType = 'Leave';
    if (existingRequest != null) {
      if (existingRequest.leaveType.toLowerCase().startsWith('permission')) {
        requestType = 'Permission';
      } else {
        requestType = 'Leave';
        _selectedLeaveType = existingRequest.leaveType;
      }
      _fromDate = _parseKey(existingRequest.fromDate) ?? DateTime.now();
      _toDate = _parseKey(existingRequest.toDate) ?? DateTime.now();
      _reasonController.text = existingRequest.reason;
    } else {
      if (activeLeaveTypes.isNotEmpty && !activeLeaveTypes.any((t) => t.name == _selectedLeaveType)) {
        _selectedLeaveType = activeLeaveTypes.first.name;
      }
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _reasonController.clear();
    }

    TimeOfDay fromTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 10, minute: 0);

    String formatTimeOfDay(TimeOfDay time) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      return DateFormat('hh:mm a').format(dt);
    }

    double calculatePermissionHours(TimeOfDay from, TimeOfDay to) {
      final fromMinutes = from.hour * 60 + from.minute;
      final toMinutes = to.hour * 60 + to.minute;
      final diffMinutes = toMinutes - fromMinutes;
      if (diffMinutes <= 0) return 0.0;
      return diffMinutes / 60.0;
    }

    String formatPermissionDuration(double hours) {
      if (hours <= 0) return '0 Hours';
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      if (h > 0 && m > 0) {
        return '$h Hour${h > 1 ? 's' : ''} $m Mins';
      } else if (h > 0) {
        return '$h Hour${h > 1 ? 's' : ''}';
      } else {
        return '$m Mins';
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double days = 1.0;
            if (_fromDate != null && _toDate != null) {
              final diff = _toDate!.difference(_fromDate!).inDays + 1;
              days = math.max(1.0, diff.toDouble());
            }

            final permHours = calculatePermissionHours(fromTime, toTime);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existingRequest != null ? 'Edit Leave Request' : 'Apply For Leave',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF414A51)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: math.min(450.0, MediaQuery.of(context).size.width * 0.85),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leave Type Dropdown
                      const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: (activeLeaveTypes.isNotEmpty && activeLeaveTypes.any((t) => t.name == _selectedLeaveType))
                            ? _selectedLeaveType
                            : (activeLeaveTypes.isNotEmpty ? activeLeaveTypes.first.name : _selectedLeaveType),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                          ),
                        ),
                        items: (activeLeaveTypes.isNotEmpty
                                ? activeLeaveTypes.map((type) => type.name).toList()
                                : [
                                    'Sick Leave',
                                    'Casual Leave',
                                    'Annual Leave',
                                    'Optional Leave',
                                    'Emergency Leave',
                                    'Work From Home',
                                    'Comp Off',
                                  ])
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedLeaveType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _fromDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _fromDate = picked;
                                        if (_toDate != null && _toDate!.isBefore(picked)) {
                                          _toDate = picked;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _fromDate != null ? DateFormat('dd MMM yyyy').format(_fromDate!) : 'Select Date',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF414A51)),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _toDate ?? DateTime.now(),
                                      firstDate: _fromDate ?? DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _toDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _toDate != null ? DateFormat('dd MMM yyyy').format(_toDate!) : 'Select Date',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF414A51)),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Duration: ${days == 1 ? '1 Day' : '$days Days'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF65A30D)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter reason / description...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (_reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a description / reason'),
                          backgroundColor: Color(0xFFC62828),
                        ),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);

                    try {
                      final fromStr = DateFormat('dd-MM-yyyy').format(_fromDate!);
                      final toStr = DateFormat('dd-MM-yyyy').format(_toDate!);

                      if (existingRequest != null) {
                        final updatedReq = existingRequest.copyWith(
                          leaveType: _selectedLeaveType,
                          fromDate: fromStr,
                          toDate: toStr,
                          numDays: days,
                          reason: _reasonController.text.trim(),
                        );

                        await ref.read(leaveRepositoryProvider).updateLeaveRequest(updatedReq);
                      } else {
                        final newReq = LeaveRequest(
                          id: 0,
                          employeeId: currentEmp.id,
                          employeeName: currentEmp.fullName,
                          employeeCustomId: currentEmp.employeeId,
                          leaveType: _selectedLeaveType,
                          fromDate: fromStr,
                          toDate: toStr,
                          numDays: days,
                          reason: _reasonController.text.trim(),
                          status: 'Pending',
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        await ref.read(leaveRepositoryProvider).submitLeaveRequest(newReq);
                      }

                      ref.invalidate(leaveRequestsProvider(currentEmp.id));
                      ref.invalidate(allLeaveRequestsProvider);

                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(existingRequest != null
                              ? 'Leave request updated successfully!'
                              : 'Leave request submitted successfully!'),
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit: $e'),
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- TODAY BANNER CARD ---
  Widget _buildTodayBannerCard(
    Employee employee,
    AsyncValue<AttendanceRecord?> todayAttendanceAsync,
  ) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(today);

    return todayAttendanceAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text('Error loading today\'s attendance: $e'),
      ),
      data: (todayRecord) {
        final hasCheckedIn = todayRecord != null && todayRecord.effectiveCheckInTime.isNotEmpty;
        final hasCheckedOut = todayRecord != null && todayRecord.checkOutTime.isNotEmpty;

        final now = DateTime.now();
        final expectedInTimeOfDay = _getEmployeeInTime(employee);
        final officialStartTime = DateTime(now.year, now.month, now.day, expectedInTimeOfDay.hour, expectedInTimeOfDay.minute);
        final officialTimeStr = _formatTimeOfDayLabel(expectedInTimeOfDay);
        final isLate = now.isAfter(officialStartTime) && !hasCheckedIn;

        final myRequestsAsync = ref.watch(myPermissionRequestsProvider(employee.id));
        PermissionRequest? todayApprovedPermission;
        PermissionRequest? todayPendingPermission;

        myRequestsAsync.whenData((requests) {
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          for (final req in requests) {
            final reqDateStr = DateFormat('yyyy-MM-dd').format(req.date);
            if (reqDateStr == todayStr || (req.date.day == now.day && req.date.month == now.month && req.date.year == now.year)) {
              if (req.status == PermissionStatus.approved) {
                todayApprovedPermission = req;
                break;
              } else if (req.status == PermissionStatus.pending) {
                todayPendingPermission = req;
              }
            }
          }
        });

        final hasApprovedPermission = todayApprovedPermission != null;
        final hasPendingPermission = todayPendingPermission != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Date + Status Pill
              Row(
                children: [
                  const Icon(Icons.access_time_filled, color: AppColors.active, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasApprovedPermission
                              ? 'Approved Permission: ${todayApprovedPermission!.fromTime} – ${todayApprovedPermission!.toTime}'
                              : hasPendingPermission
                                  ? 'Permission Pending: ${todayPendingPermission!.fromTime} – ${todayPendingPermission!.toTime}'
                                  : isLate
                                      ? 'You are late today. Please apply for permission or check in directly.'
                                      : 'Expected Check-in Time: $officialTimeStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: (isLate && !hasApprovedPermission && !hasPendingPermission) ? FontWeight.w600 : FontWeight.w500,
                            color: hasApprovedPermission
                                ? const Color(0xFF15803D)
                                : hasPendingPermission
                                    ? const Color(0xFFB45309)
                                    : isLate
                                        ? const Color(0xFFC2410C)
                                        : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(todayRecord),
                ],
              ),
              const SizedBox(height: 16),

              // Render Approved / Pending Permission Card OR Late Arrival Warning Banner
              if (!hasCheckedIn && hasApprovedPermission) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            '✓ Permission Approved',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${todayApprovedPermission!.permissionType.label} • ${todayApprovedPermission!.durationMinutes} minutes',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '${todayApprovedPermission!.fromTime} – ${todayApprovedPermission!.toTime}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You have an approved permission. You can check in when you arrive.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ] else if (!hasCheckedIn && hasPendingPermission) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Text(
                            '⏳ Permission Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${todayPendingPermission!.permissionType.label} • ${todayPendingPermission!.durationMinutes} minutes',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '${todayPendingPermission!.fromTime} – ${todayPendingPermission!.toTime}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your request is pending admin review. You can check in when you arrive.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ] else if (!hasCheckedIn && isLate) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD8A8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                            children: [
                              TextSpan(
                                text: '⚠️ Late Arrival: Official time is $officialTimeStr. ',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () {
                                    final nowTod = TimeOfDay.now();
                                    final nowMins = nowTod.hour * 60 + nowTod.minute;
                                    final expMins = expectedInTimeOfDay.hour * 60 + expectedInTimeOfDay.minute;
                                    final toTod = nowMins > expMins
                                        ? nowTod
                                        : TimeOfDay(
                                            hour: (expectedInTimeOfDay.hour + ((expectedInTimeOfDay.minute + 30) ~/ 60)) % 24,
                                            minute: (expectedInTimeOfDay.minute + 30) % 60,
                                          );
                                    context.go('/permission/apply', extra: {
                                      'fromTime': expectedInTimeOfDay,
                                      'toTime': toTod,
                                    });
                                  },
                                  child: const Text(
                                    'Apply for Permission',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC2410C),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' or tap Check In below.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Primary Action Button
              if (!hasCheckedIn) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.active,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (hasApprovedPermission || hasPendingPermission || !isLate) {
                        _openVerificationDialog(
                          date: today,
                          isCheckOut: false,
                          existingRecord: todayRecord,
                        );
                      } else {
                        _showLateCheckInDialog(
                          today: today,
                          todayRecord: todayRecord,
                          officialTimeStr: officialTimeStr,
                          expectedInTimeOfDay: expectedInTimeOfDay,
                        );
                      }
                    },
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text(
                      'Check In Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else if (!hasCheckedOut) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF414A51),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openVerificationDialog(
                      date: today,
                      isCheckOut: true,
                      existingRecord: todayRecord,
                    ),
                    icon: const Icon(Icons.logout, size: 22),
                    label: const Text(
                      'Check Out Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text(
                        'Shift Attendance Complete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Secondary Status Summary
              if (!hasCheckedIn) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade500,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Check Out Attendance',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ] else if (!hasCheckedOut) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF81C784)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      'Checked In at ${todayRecord.effectiveCheckInTime}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 16),

              // Stat Chips Row
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.login,
                      iconColor: const Color(0xFF2E7D32),
                      label: 'Check In',
                      value: hasCheckedIn ? todayRecord.effectiveCheckInTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.logout,
                      iconColor: const Color(0xFFC62828),
                      label: 'Check Out',
                      value: hasCheckedOut ? todayRecord.checkOutTime : '--:--',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatChip(
                      icon: Icons.timelapse,
                      iconColor: AppColors.active,
                      label: 'Work Hrs',
                      value: todayRecord != null && todayRecord.totalHours > 0
                          ? '${todayRecord.totalHours} hrs'
                          : '--',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(AttendanceRecord? record) {
    if (record == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text(
          'Not Marked',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
    Color color;
    switch (record.status) {
      case 'Present':
      case 'Completed':
        color = const Color(0xFF2E7D32);
        break;
      case 'Late':
      case 'Insufficient hours':
        color = const Color(0xFFE65100);
        break;
      case 'Checked Out':
        color = const Color(0xFF414A51);
        break;
      case 'Absent':
        color = const Color(0xFFC62828);
        break;
      default:
        color = AppColors.active;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        record.status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildCompactStatChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CALENDAR WIDGET ---
  Widget _buildCalendar(List<AttendanceRecord> attendanceRecords, List<LeaveRequest> leaveRequests) {
    final attendanceMap = <String, AttendanceRecord>{};
    for (final rec in attendanceRecords) {
      attendanceMap[rec.date] = rec;
    }

    final today = DateTime.now();
    final todayKey = _formatKey(DateTime(today.year, today.month, today.day));
    final leaveDates = <String>{};
    for (final req in leaveRequests) {
      if (req.status != 'Approved' && req.status != 'Pending') continue;
      for (final d in [...req.approvedDates, ...req.lopDates]) {
        if (d != todayKey) {
          leaveDates.add(d);
        }
      }
      if (req.status == 'Pending') {
        final from = _parseKey(req.fromDate);
        final to = _parseKey(req.toDate);
        if (from != null && to != null) {
          var curr = from;
          while (!curr.isAfter(to)) {
            final key = _formatKey(curr);
            if (key != todayKey) {
              leaveDates.add(key);
            }
            curr = curr.add(const Duration(days: 1));
          }
        }
      }
    }

    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final totalGridCells = ((startWeekday + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.active),
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.active),
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20, color: AppColors.active),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day of week labels
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          // Responsive 7-Column Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(year, month, dayNumber);
              final key = _formatKey(date);
              final isToday = key == todayKey;
              final isLeave = leaveDates.contains(key);
              final record = attendanceMap[key];
              final isAttendance = record != null;

              Color? bg;
              if (isLeave) {
                bg = const Color(0xFFE53935);
              } else if (isAttendance) {
                bg = record.status == 'Late'
                    ? const Color(0xFFE65100)
                    : const Color(0xFF2E7D32);
              } else if (isToday) {
                bg = const Color(0xFFD6ECFF);
              }

              return MouseRegion(
                cursor: isToday ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: isToday
                      ? () => _openVerificationDialog(
                            date: date,
                            isCheckOut: record != null && record.checkOutTime.isEmpty,
                            existingRecord: record,
                          )
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && bg == null
                          ? Border.all(color: AppColors.active, width: 1.5)
                          : isLeave
                              ? Border.all(color: const Color(0xFF9CC70A), width: 1.2)
                              : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLeave || isAttendance || isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isAttendance || isLeave ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (isLeave)
                          const Positioned(
                            right: 3,
                            top: 3,
                            child: Icon(Icons.event_busy, size: 9, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Legend using Wrap for zero overflow on mobile
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                _legend(const Color(0xFFD6ECFF), 'Today'),
                _legend(const Color(0xFFE53935), 'Leave'),
                _legend(const Color(0xFF2E7D32), 'Present'),
                _legend(const Color(0xFFE65100), 'Late'),
                _legend(const Color(0xFF9C27B0), 'Holiday'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      );

  TimeOfDay _getEmployeeInTime(Employee emp) {
    final inTimeStr = emp.inTime.trim();
    if (inTimeStr.isNotEmpty) {
      try {
        final isPm = inTimeStr.toUpperCase().contains('PM');
        final isAm = inTimeStr.toUpperCase().contains('AM');
        final digits = inTimeStr.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = digits.split(':');
        if (parts.length == 2) {
          int h = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          if (isPm && h < 12) h += 12;
          if (isAm && h == 12) h = 0;
          return TimeOfDay(hour: h, minute: m);
        }
      } catch (_) {}
    }
    return const TimeOfDay(hour: 9, minute: 30);
  }

  String _formatTimeOfDayLabel(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _showLateCheckInDialog({
    required DateTime today,
    required AttendanceRecord? todayRecord,
    required String officialTimeStr,
    required TimeOfDay expectedInTimeOfDay,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Late Check-in Alert',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You are checking in after the official start time ($officialTimeStr). Would you like to request permission or proceed with check-in?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF414A51),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final nowTod = TimeOfDay.now();
              final nowMins = nowTod.hour * 60 + nowTod.minute;
              final expMins = expectedInTimeOfDay.hour * 60 + expectedInTimeOfDay.minute;
              final toTod = nowMins > expMins
                  ? nowTod
                  : TimeOfDay(
                      hour: (expectedInTimeOfDay.hour + ((expectedInTimeOfDay.minute + 30) ~/ 60)) % 24,
                      minute: (expectedInTimeOfDay.minute + 30) % 60,
                    );
              context.go('/permission/apply', extra: {
                'fromTime': expectedInTimeOfDay,
                'toTime': toTod,
              });
            },
            child: const Text(
              'Apply Permission',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openVerificationDialog(
                date: today,
                isCheckOut: false,
                existingRecord: todayRecord,
              );
            },
            child: const Text(
              'Check In Anyway',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _openVerificationDialog({
    required DateTime date,
    required bool isCheckOut,
    AttendanceRecord? existingRecord,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AttendanceVerificationDialog(
        date: date,
        isCheckOut: isCheckOut,
        existingRecord: existingRecord,
        attendanceRepository: ref.read(attendanceRepositoryProvider),
        currentEmployee: ref.read(currentEmployeeProvider)!,
        onAttendanceMarked: () {
          final empId = ref.read(currentEmployeeProvider)!.id;
          ref.invalidate(attendanceRecordsProvider(empId));
          ref.invalidate(todayAttendanceRecordProvider(empId));
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildSalaryLopTab(Employee currentEmp, AsyncValue<List<LeaveRequest>> leaveRequestsAsync) {
    final leaves = leaveRequestsAsync.valueOrNull ?? [];

    final grossSalary = currentEmp.salaryTotalCtc > 0
        ? currentEmp.salaryTotalCtc
        : (currentEmp.salaryBasic > 0
            ? (currentEmp.salaryBasic + currentEmp.salaryHra + currentEmp.salaryAllowances)
            : 35000.0);

    const workingDays = 26;
    final perDayRate = grossSalary > 0 ? (grossSalary / workingDays) : 0.0;

    final approvedLeaves = leaves.where((l) => l.status.toLowerCase() == 'approved').toList();
    final approvedLeaveDays = approvedLeaves.fold<double>(
      0.0,
      (sum, l) => sum + (l.numDays > 0 ? l.numDays : 1.0),
    );

    final lopLeaves = leaves.where((l) {
      final st = l.status.toLowerCase();
      final type = l.leaveType.toLowerCase();
      return (st == 'approved' && (type.contains('lop') || type.contains('unpaid') || type.contains('loss of pay'))) ||
          st == 'denied' ||
          st == 'rejected';
    }).toList();

    final lopDays = lopLeaves.fold<double>(
      0.0,
      (sum, l) => sum + (l.numDays > 0 ? l.numDays : (l.lopDates.isNotEmpty ? l.lopDates.length.toDouble() : 1.0)),
    );

    final lopDeduction = lopDays * perDayRate;
    final finalPayableSalary = (grossSalary - lopDeduction).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Final Payable Salary (Current Month)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${finalPayableSalary.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lopDays > 0
                        ? '${lopDays.toStringAsFixed(0)} Day(s) LOP Deduction (-₹${lopDeduction.toStringAsFixed(0)}) applied'
                        : 'No LOP Deductions applied this month 🎉',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Responsive 2-Card Layout (Side-by-Side on Desktop, Stacked on Mobile)
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 700;

                final salaryCard = Container(
                  padding: const EdgeInsets.all(18),
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
                    children: [
                      const Text(
                        'Salary Breakdown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildRowDetail('Gross Monthly Salary', '₹${grossSalary.toStringAsFixed(0)}'),
                      const SizedBox(height: 12),
                      _buildRowDetail('Working Days', '$workingDays Days'),
                      const SizedBox(height: 12),
                      _buildRowDetail('Per Day Salary Rate', '₹${perDayRate.toStringAsFixed(0)}'),
                    ],
                  ),
                );

                final leaveImpactCard = Container(
                  padding: const EdgeInsets.all(18),
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
                    children: [
                      const Text(
                        'Leave Impact',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _buildRowDetail('Approved Leave Days', '${approvedLeaveDays.toStringAsFixed(0)} Days'),
                      const SizedBox(height: 12),
                      _buildRowDetail('LOP Days', '${lopDays.toStringAsFixed(0)} Days'),
                      const SizedBox(height: 12),
                      _buildRowDetail('LOP Deduction', '₹${lopDeduction.toStringAsFixed(0)}'),
                    ],
                  ),
                );

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: salaryCard),
                      const SizedBox(width: 16),
                      Expanded(child: leaveImpactCard),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      salaryCard,
                      const SizedBox(height: 14),
                      leaveImpactCard,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class AttendanceVerificationDialog extends ConsumerStatefulWidget {
  const AttendanceVerificationDialog({
    super.key,
    required this.date,
    required this.isCheckOut,
    this.existingRecord,
    required this.attendanceRepository,
    required this.currentEmployee,
    required this.onAttendanceMarked,
  });

  final DateTime date;
  final bool isCheckOut;
  final AttendanceRecord? existingRecord;
  final AttendanceRepository attendanceRepository;
  final Employee currentEmployee;
  final VoidCallback onAttendanceMarked;

  @override
  ConsumerState<AttendanceVerificationDialog> createState() => _AttendanceVerificationDialogState();
}

class _AttendanceVerificationDialogState extends ConsumerState<AttendanceVerificationDialog> {
  bool _verifying = false;
  String? _message;
  bool? _withinAllowedRadius;
  String? _locationMessage;
  static const double _maxAllowedGpsAccuracyMeters = 200;

  String _formatKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _refreshLocationGate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshLocationGate() async {
    try {
      final emp = widget.currentEmployee;
      final settings = await widget.attendanceRepository.getAttendanceSettings();
      final bool isSite = emp.isDynamicEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0);
      final double targetLat = isSite ? emp.siteLatitude : settings.officeLatitude;
      final double targetLng = isSite ? emp.siteLongitude : settings.officeLongitude;
      final int targetRadius = isSite ? emp.siteAllowedRadiusMeters : settings.allowedAttendanceRadiusMeters;
      final bool requireGps = isSite ? emp.siteRequireGpsVerification : settings.requireGpsVerification;

      if (!requireGps) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = true;
          _locationMessage = null;
        });
        return;
      }

      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (!mounted) return;
          setState(() {
            _withinAllowedRadius = false;
            _locationMessage = 'Location services are turned off on this device.';
          });
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = false;
          _locationMessage = 'Location permission was denied.';
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _withinAllowedRadius = false;
          _locationMessage = 'Location permission is permanently denied. Enable it in system settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final distance = Geolocator.distanceBetween(
        targetLat,
        targetLng,
        position.latitude,
        position.longitude,
      );
      final withinRadius = !(targetLat == 0 && targetLng == 0) &&
          distance <= targetRadius;
      if (!mounted) return;
      setState(() {
        _withinAllowedRadius = withinRadius;
        _locationMessage = withinRadius
            ? null
            : isSite
                ? 'You are not at your site location. Please go to your site location.'
                : 'You are not at the office. Please go to the office location.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _withinAllowedRadius = false;
        _locationMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _checkItem({
    required String label,
    required bool done,
    required IconData icon,
  }) {
    final color = done ? const Color(0xFF2E7D32) : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _authenticateAndProceed() async {
    if (_verifying) return;

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      final actionTitle = widget.isCheckOut ? 'Check Out' : 'Check In';
      final now = DateTime.now();
      final dateKey = _formatKey(widget.date);

      final emp = widget.currentEmployee;
      final settings = await widget.attendanceRepository.getAttendanceSettings();
      final bool isSite = emp.isDynamicEmployee && (emp.siteLatitude != 0 || emp.siteLongitude != 0);
      final bool requireGps = isSite ? emp.siteRequireGpsVerification : settings.requireGpsVerification;
      double currentLat = 0.0;
      double currentLng = 0.0;

      if (requireGps) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (position.accuracy > _maxAllowedGpsAccuracyMeters) {
          throw Exception(
            'GPS accuracy is too low (${position.accuracy.toStringAsFixed(1)}m). Move to an open area and try again.',
          );
        }
        if (!kIsWeb && position.isMocked) {
          throw Exception('Mock location detected. Turn off fake GPS and try again.');
        }
        currentLat = position.latitude;
        currentLng = position.longitude;
      }

      AttendanceVerificationResult verifyResult;
      if (widget.isCheckOut) {
        verifyResult = await widget.attendanceRepository.verifyCheckOut(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          profileImageUrl: widget.currentEmployee.profileImageUrl,
          currentLatitude: currentLat,
          currentLongitude: currentLng,
        );
      } else {
        verifyResult = await widget.attendanceRepository.verifyAttendance(
          employeeId: widget.currentEmployee.id,
          employeeName: widget.currentEmployee.fullName,
          date: dateKey,
          profileImageUrl: widget.currentEmployee.profileImageUrl,
          scheduledCheckInTime: widget.currentEmployee.inTime,
          currentLatitude: currentLat,
          currentLongitude: currentLng,
        );
      }

      if (!verifyResult.allowed) {
        if (!mounted) return;
        setState(() => _message = verifyResult.message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verifyResult.message)));
        return;
      }

      if (!mounted) return;
      setState(() => _message = verifyResult.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionTitle completed successfully!')),
      );
      widget.onAttendanceMarked();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _unmarkAttendance() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final now = DateTime.now();
      final dateKey = _formatKey(widget.date);
      final time = DateFormat('HH:mm:ss').format(now);

      await widget.attendanceRepository.unmarkAttendance(
        employeeId: widget.currentEmployee.id,
        date: dateKey,
      );
      await widget.attendanceRepository.logAttendanceAttempt(
        employeeId: widget.currentEmployee.id,
        employeeName: widget.currentEmployee.fullName,
        date: dateKey,
        time: time,
        verificationStatus: 'Unmarked',
        similarityScore: 0.0,
        message: 'Attendance unmarked successfully.',
      );
      if (!mounted) return;
      setState(() => _message = 'Attendance unmarked successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance unmarked successfully.')),
      );
      widget.onAttendanceMarked();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _cancel() async {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPerformAction = _withinAllowedRadius ?? false;
    final actionText = widget.isCheckOut ? 'Check Out' : 'Check In';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('$actionText Attendance'),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('dd/MM/yyyy').format(widget.date),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE').format(widget.date),
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification checklist',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _checkItem(
                      label: 'GPS location is within office radius',
                      done: _withinAllowedRadius == true,
                      icon: Icons.location_on_outlined,
                    ),
                    _checkItem(
                      label: 'GPS verification only',
                      done: true,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
              ),

              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _message!.contains('completed') || _message!.contains('successful')
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
              if (_locationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _locationMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _withinAllowedRadius == true
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE53935),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        if (widget.existingRecord != null)
          TextButton(
            onPressed: _verifying ? null : _unmarkAttendance,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
            child: Text(_verifying ? 'Working...' : 'Unmark Attendance'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isCheckOut ? const Color(0xFF414A51) : AppColors.active,
            foregroundColor: Colors.white,
          ),
          onPressed: canPerformAction ? _authenticateAndProceed : null,
          child: Text(_verifying ? 'Verifying...' : actionText),
        ),
      ],
    );
  }
}

class _DailyHistoryItem {
  final DateTime date;
  final String status;
  final String checkIn;
  final String checkOut;
  final String duration;
  final String note;

  _DailyHistoryItem({
    required this.date,
    required this.status,
    this.checkIn = '',
    this.checkOut = '',
    this.duration = '',
    this.note = '',
  });
}
