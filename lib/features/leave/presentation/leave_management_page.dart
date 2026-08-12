import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  int get _activeFilterCount {
    int count = 0;
    if (_filterEmployeeId != null) count++;
    if (_filterStatus != 'All Status') count++;
    if (_filterLeaveType != 'All Leave Types') count++;
    if (_filterDepartment != 'All Departments') count++;
    if (_filterDesignation != 'All Designations') count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _filterEmployeeId = null;
      _filterStatus = 'All Status';
      _filterLeaveType = 'All Leave Types';
      _filterDepartment = 'All Departments';
      _filterDesignation = 'All Designations';
    });
  }

  // Helper date parsing
  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return null;
      if (dateStr.contains('T')) dateStr = dateStr.split('T').first;
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        final c = int.parse(parts[2]);
        if (a > 1000) {
          // yyyy-MM-dd
          return DateTime(a, b, c);
        } else {
          // dd-MM-yyyy
          return DateTime(c, b, a);
        }
      }
    } catch (_) {}
    return null;
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

  Color _parseHexColor(String hexString) {
    try {
      String cleanHex = hexString.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF0D8A4E);
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
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D8A4E))),
        error: (err, stack) => Center(
          child: SelectableText('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (employees) {
          final allRequests = allRequestsAsync.value ?? [];
          final leaveTypes = leaveTypesAsync.value ?? [];
          final pendingRequestsCount = allRequests.where((r) => r.status == 'Pending').length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header: Compact title & Apply Leave Action
                    _buildTopHeader(context, employees, leaveTypes, currentEmp, isMobile),
                    const SizedBox(height: 16),

                    // Modern Navigation Tab Bar
                    _buildNavigationBar(pendingRequestsCount, isMobile),
                    const SizedBox(height: 20),

                    // Animated Active Tab Switcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_activeTab),
                        child: switch (_activeTab) {
                          LeaveTab.dashboard => _buildDashboardTab(allRequests, employees, leaveTypes, isMobile),
                          LeaveTab.requests => _buildRequestsTab(allRequests, employees, leaveTypes, isMobile),
                          LeaveTab.calendar => _buildCalendarTab(allRequests, employees, leaveTypes, isMobile),
                          LeaveTab.permissions => _buildPermissionsTab(employees, leaveTypes, isMobile),
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
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
    bool isMobile,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D8A4E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF0D8A4E)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (!isMobile)
                const Text(
                  'Manage employee leave requests, balances, and policies',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D8A4E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: () => _showApplyLeaveDialog(context, employees, leaveTypes, currentEmp),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            isMobile ? 'Apply Leave' : '+ Apply Leave for Employee',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.bold,
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
    final activeLeaveTypes = leaveTypes.where((t) => t.isActive).toList();
    Employee? selectedEmployee = currentEmp ?? (employees.isNotEmpty ? employees.first : null);
    LeaveType? selectedLeaveType = activeLeaveTypes.isNotEmpty ? activeLeaveTypes.first : (leaveTypes.isNotEmpty ? leaveTypes.first : null);
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    final reasonController = TextEditingController();
    bool isEmergency = false;

    String requestType = 'Leave';
    TimeOfDay fromTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay toTime = const TimeOfDay(hour: 11, minute: 0);

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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final days = toDate.difference(fromDate).inDays + 1;
          final permHours = calculatePermissionHours(fromTime, toTime);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Apply Leave for Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Employee>(
                      initialValue: selectedEmployee,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: employees.map((e) {
                        return DropdownMenuItem<Employee>(
                          value: e,
                          child: Text('${e.fullName} (${e.employeeId})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedEmployee = val),
                    ),
                    const SizedBox(height: 14),

                    // Request Type Dropdown
                    const Text('Request Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: requestType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: ['Leave', 'Permission']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => requestType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    if (requestType == 'Leave') ...[
                      const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<LeaveType>(
                        initialValue: selectedLeaveType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: (activeLeaveTypes.isNotEmpty ? activeLeaveTypes : leaveTypes).map((t) {
                          return DropdownMenuItem<LeaveType>(
                            value: t,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _parseHexColor(t.colorHex),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(t.name, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedLeaveType = val),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
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
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd-MM-yyyy').format(fromDate),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
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
                                const Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
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
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd-MM-yyyy').format(toDate),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
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
                      const SizedBox(height: 8),
                      Text(
                        'Total Duration: ${days > 0 ? days : 1} day(s)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D8A4E)),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      // Permission Time Fields
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: fromTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        fromTime = picked;
                                        final fromMin = picked.hour * 60 + picked.minute;
                                        final toMin = toTime.hour * 60 + toTime.minute;
                                        if (toMin <= fromMin) {
                                          toTime = TimeOfDay(hour: (picked.hour + 2) % 24, minute: picked.minute);
                                        }
                                      });
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
                                        Text(formatTimeOfDay(fromTime), style: const TextStyle(fontSize: 13)),
                                        const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
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
                                const Text('To Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: toTime,
                                    );
                                    if (picked != null) {
                                      setDialogState(() => toTime = picked);
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
                                        Text(formatTimeOfDay(toTime), style: const TextStyle(fontSize: 13)),
                                        const Icon(Icons.access_time, size: 16, color: Color(0xFF64748B)),
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
                        'Duration: ${formatPermissionDuration(permHours)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D8A4E)),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (requestType == 'Leave') ...[
                      // Employee Policy Warning Banner
                      if (selectedEmployee != null && selectedEmployee!.leavePolicy == 'No Leave') ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ You are currently configured with "No Leave". This request may be treated as LOP. The final decision will be made by the Super Admin.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else if (selectedEmployee != null && selectedEmployee!.leavePolicy == 'Manual Allocation') ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ Your leave quota for this month has been exhausted. The requested leave may be treated as LOP unless the Super Admin approves it as Paid Leave.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      const Text('Reason / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter reason / description...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Emergency Leave Request', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        value: isEmergency,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => isEmergency = v ?? false),
                      ),
                    ] else ...[
                      const Text('Reason / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter reason / description...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8A4E),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (selectedEmployee == null) return;
                  if (requestType == 'Leave' && selectedLeaveType == null) return;

                  LeaveRequest newRequest;
                  if (requestType == 'Leave') {
                    final fromStr = DateFormat('dd-MM-yyyy').format(fromDate);
                    final toStr = DateFormat('dd-MM-yyyy').format(toDate);

                    newRequest = LeaveRequest(
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
                  } else {
                    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
                    final fromTimeStr = formatTimeOfDay(fromTime);
                    final toTimeStr = formatTimeOfDay(toTime);

                    newRequest = LeaveRequest(
                      id: 0,
                      employeeId: selectedEmployee!.id,
                      employeeName: selectedEmployee!.fullName,
                      employeeCustomId: selectedEmployee!.employeeId,
                      leaveType: 'Permission ($fromTimeStr - $toTimeStr)',
                      fromDate: todayStr,
                      toDate: todayStr,
                      numDays: permHours / 8.0,
                      reason: reasonController.text.trim(),
                      status: 'Pending',
                      createdAt: DateTime.now().toIso8601String(),
                      approvedDates: [],
                      lopDates: [],
                      isEmergency: false,
                    );
                  }

                  await ref.read(leaveRepositoryProvider).submitLeaveRequest(newRequest);
                  ref.invalidate(allLeaveRequestsProvider);
                  ref.invalidate(leaveRequestsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. NAVIGATION TAB BAR
  // ---------------------------------------------------------------------------
  Widget _buildNavigationBar(int pendingCount, bool isMobile) {
    final tabs = [
      (LeaveTab.dashboard, 'Dashboard', Icons.dashboard_outlined, null),
      (LeaveTab.requests, 'Requests', Icons.assignment_outlined, pendingCount),
      (LeaveTab.calendar, 'Calendar', Icons.calendar_today_outlined, null),
      (LeaveTab.permissions, isMobile ? 'Settings' : 'Permissions', Icons.tune_outlined, null),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: tabs.map((tabInfo) {
          final tab = tabInfo.$1;
          final label = tabInfo.$2;
          final icon = tabInfo.$3;
          final count = tabInfo.$4;
          final isActive = _activeTab == tab;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 10 : 12,
                  horizontal: isMobile ? 2 : 10,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: isMobile ? 16 : 18,
                      color: isActive ? const Color(0xFF0D8A4E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive ? const Color(0xFF0D8A4E) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (count != null && count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF0D8A4E) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
    bool isMobile,
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
        // KPI Summary Cards 2-Column Grid on Mobile
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.35 : 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildKpiCard(
              title: 'Pending Requests',
              value: '$pendingCount',
              icon: Icons.hourglass_empty_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              subtitle: 'Awaiting approval',
            ),
            _buildKpiCard(
              title: 'On Leave Today',
              value: '${onLeaveTodayRequests.length}',
              icon: Icons.person_off_outlined,
              iconBg: const Color(0xFFD1FAE5),
              iconColor: const Color(0xFF059669),
              subtitle: 'Employees out today',
            ),
            _buildKpiCard(
              title: 'Approved Month',
              value: '$approvedThisMonthCount',
              icon: Icons.check_circle_outline_rounded,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF2563EB),
              subtitle: 'In current month',
            ),
            _buildKpiCard(
              title: 'Total Employees',
              value: '${employees.length}',
              icon: Icons.people_outline_rounded,
              iconBg: const Color(0xFFF3E8FF),
              iconColor: const Color(0xFF9333EA),
              subtitle: 'Active staff',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Split Sections: Recent Requests & On Leave Today
        if (isMobile)
          Column(
            children: [
              _buildRecentRequestsCard(recentRequests, isMobile),
              const SizedBox(height: 16),
              _buildOnLeaveTodayCard(onLeaveTodayRequests, employees),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildRecentRequestsCard(recentRequests, isMobile)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildOnLeaveTodayCard(onLeaveTodayRequests, employees)),
            ],
          ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsCard(List<LeaveRequest> recentRequests, bool isMobile) {
    final displayList = recentRequests.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Text(
                'Recent Requests',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => setState(() => _activeTab = LeaveTab.requests),
                child: const Row(
                  children: [
                    Text('View all', style: TextStyle(fontSize: 12, color: Color(0xFF0D8A4E), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 14, color: Color(0xFF0D8A4E)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No leave requests found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final req = displayList[index];
                return _buildRecentRequestRow(req, isMobile);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestRow(LeaveRequest req, bool isMobile) {
    final initials = _getInitials(req.employeeName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  initials,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${req.leaveType} · ${_formatDateDisplay(req.fromDate)} · ${_formatDurationDisplay(req)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusBadge(req.status),
            ],
          ),
          if (req.status == 'Pending') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _handleDenyRequest(req),
                    child: const Text('Deny', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D8A4E),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleApproveRequest(req),
                    child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showSuperAdminApprovalDialog(req),
                icon: const Icon(Icons.edit_note, size: 14, color: Color(0xFF475569)),
                label: const Text('Change Decision', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnLeaveTodayCard(List<LeaveRequest> onLeaveTodayRequests, List<Employee> employees) {
    final todayFormatted = DateFormat('d MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            'On Leave Today — $todayFormatted',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          if (onLeaveTodayRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No employees on leave today.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: onLeaveTodayRequests.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                        radius: 14,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          _getInitials(req.employeeName),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.employeeName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              '${emp.department} · ${req.leaveType}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. REQUESTS TAB & FILTER BOTTOM SHEET
  // ---------------------------------------------------------------------------
  Widget _buildRequestsTab(
    List<LeaveRequest> allRequests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
    bool isMobile,
  ) {
    // Filter Requests
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Search & Filter Header Bar
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by employee or leave type...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showFilterBottomSheet(context, employees, leaveTypes),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _activeFilterCount > 0 ? const Color(0xFFECFDF5) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _activeFilterCount > 0 ? const Color(0xFF0D8A4E) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: _activeFilterCount > 0 ? const Color(0xFF0D8A4E) : const Color(0xFF64748B),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _activeFilterCount > 0 ? const Color(0xFF0D8A4E) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D8A4E),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter chips bar if any filter is active
        if (_activeFilterCount > 0) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_filterEmployeeId != null)
                  _buildFilterChip('Emp ID: $_filterEmployeeId', () => setState(() => _filterEmployeeId = null)),
                if (_filterStatus != 'All Status')
                  _buildFilterChip('Status: $_filterStatus', () => setState(() => _filterStatus = 'All Status')),
                if (_filterLeaveType != 'All Leave Types')
                  _buildFilterChip('Type: $_filterLeaveType', () => setState(() => _filterLeaveType = 'All Leave Types')),
                if (_filterDepartment != 'All Departments')
                  _buildFilterChip('Dept: $_filterDepartment', () => setState(() => _filterDepartment = 'All Departments')),
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Requests Cards List
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No leave requests match the selected filters.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  department: 'General',
                  designation: '',
                  employmentType: '',
                  joiningDate: '',
                  status: 'Active',
                ),
              );
              final typeObj = leaveTypes.firstWhere(
                (t) => t.name.toLowerCase() == req.leaveType.toLowerCase(),
                orElse: () => LeaveType(id: 0, name: req.leaveType, description: '', colorHex: '#0D8A4E'),
              );

              return _buildRequestCard(req, emp, typeObj);
            },
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, List<Employee> employees, List<LeaveType> leaveTypes) {
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

    final typeOptions = ['All Leave Types', ...leaveTypes.map((t) => t.name)];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                        'Filter Requests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearAllFilters();
                          setSheetState(() {});
                        },
                        child: const Text('Reset All', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text('Employee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    initialValue: _filterEmployeeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All Employees')),
                      ...employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.fullName))),
                    ],
                    onChanged: (v) => setSheetState(() => _filterEmployeeId = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: ['All Status', 'Pending', 'Approved', 'Denied']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => _filterStatus = v ?? 'All Status'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _filterLeaveType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setSheetState(() => _filterLeaveType = v ?? 'All Leave Types'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Department', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _filterDepartment,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setSheetState(() => _filterDepartment = v ?? 'All Departments'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Designation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _filterDesignation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: designationOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setSheetState(() => _filterDesignation = v ?? 'All Designations'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D8A4E),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest req, Employee emp, LeaveType leaveTypeObj) {
    final color = _parseHexColor(leaveTypeObj.colorHex);
    final isPending = req.status == 'Pending';

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Employee Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  _getInitials(req.employeeName),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.employeeName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${req.employeeCustomId.isNotEmpty ? req.employeeCustomId : 'EMP'} · ${emp.department}${emp.designation.isNotEmpty ? ' • ${emp.designation}' : ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(req.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Leave Info Pill & Date Range
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.leaveType,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDateDisplay(req.fromDate)} — ${_formatDateDisplay(req.toDate)} · ${_formatDurationDisplay(req)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: "${req.reason}"',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                emp.leaveType == 'No Leave'
                    ? 'Leave Policy: No Leave allocated'
                    : (emp.leaveType == 'Once a Month' || emp.leaveType == 'Manual Allocation')
                        ? 'Allowed quota: ${emp.allowedLeaves == emp.allowedLeaves.toInt() ? emp.allowedLeaves.toInt() : emp.allowedLeaves} days (${emp.leaveType})'
                        : 'Leave Policy: ${emp.leaveType.isNotEmpty ? emp.leaveType : "As Needed"}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              InkWell(
                onTap: () => _showAuditHistoryDialog(req),
                child: const Text(
                  'Audit history',
                  style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),

          // Full-width Bottom Action Buttons for Requests
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleDenyRequest(req),
                    child: const Text('Deny', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      backgroundColor: const Color(0xFF0D8A4E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleApproveRequest(req),
                    child: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showSuperAdminApprovalDialog(req),
                icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0D8A4E)),
                label: const Text('Change Decision', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D8A4E))),
              ),
            ),
          ],
        ],
      ),
    );

    if (!isPending) return cardContent;

    return Dismissible(
      key: ValueKey('req_${req.id}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _handleApproveRequest(req);
        } else {
          await _handleDenyRequest(req);
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF059669)),
            SizedBox(width: 6),
            Text('Approve', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Deny', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            SizedBox(width: 6),
            Icon(Icons.cancel, color: Color(0xFFDC2626)),
          ],
        ),
      ),
      child: cardContent,
    );
  }

  void _showAuditHistoryDialog(LeaveRequest req) {
    showDialog(
      context: context,
      builder: (ctx) {
        final logsAsync = ref.watch(leaveAuditLogsProvider(req.id));
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Audit History - ${req.employeeName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: logsAsync.when(
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Color(0xFF0D8A4E)))),
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
                      leading: const Icon(Icons.history, size: 20, color: Color(0xFF64748B)),
                      title: Text(log['action'] as String? ?? 'Action', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'By: ${log['performed_by'] ?? 'System'} · ${log['timestamp'] ?? ''}\n${log['details'] ?? ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
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
    bool isMobile,
  ) {
    final filteredRequests = allRequests.where((req) {
      if (_filterEmployeeId != null && req.employeeId != _filterEmployeeId) return false;
      return true;
    }).toList();

    final calendarView = _buildCalendarGrid(filteredRequests, employees, leaveTypes, isMobile);
    final sidePanel = _buildCalendarDayDetailPanel(filteredRequests, employees, leaveTypes);

    if (isMobile) {
      return Column(
        children: [
          calendarView,
          const SizedBox(height: 16),
          sidePanel,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: calendarView),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: sidePanel),
      ],
    );
  }

  Widget _buildCalendarGrid(
    List<LeaveRequest> requests,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
    bool isMobile,
  ) {
    final monthStr = DateFormat('MMMM yyyy').format(_focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final totalGridCells = startingWeekday + daysInMonth;
    final rowCount = (totalGridCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Month Switcher Header
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
              if (!isMobile)
                SizedBox(
                  width: 180,
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
          const SizedBox(height: 12),

          // Weekday Labels
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rowCount * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
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

              final now = DateTime.now();
              final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;

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
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFECFDF5) : (isToday ? const Color(0xFFF0FDF4) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0D8A4E)
                          : (isToday ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                      width: isSelected || isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF0D8A4E) : const Color(0xFF334155),
                        ),
                      ),
                      if (matching.isNotEmpty)
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: matching.take(3).map((r) {
                                final isPend = r.status == 'Pending';
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isPend ? const Color(0xFFF59E0B) : const Color(0xFF0D8A4E),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Wrapped Non-Overflowing Legend Bar
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0D8A4E), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Approved', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Pending', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              ),
              const Text(
                'Tap date for details',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            formattedDateTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          Text(
            '${dayRequests.length} employee${dayRequests.length == 1 ? '' : 's'} on leave',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (dayRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No employees on leave for this date.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayRequests.length,
              separatorBuilder: (ctx, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final req = dayRequests[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFCBD5E1),
                            child: Text(
                              _getInitials(req.employeeName),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              req.employeeName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                          _buildStatusBadge(req.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${req.leaveType} · ${_formatDateDisplay(req.fromDate)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                      ),
                      if (req.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reason: "${req.reason}"',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. PERMISSIONS & LEAVE TYPES TAB (MOBILE-FIRST CARDS)
  // ---------------------------------------------------------------------------
  Widget _buildPermissionsTab(List<Employee> employees, List<LeaveType> leaveTypes, bool isMobile) {
    final overridesAsync = ref.watch(employeeOverridesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Leave Types Cards List (No overflow DataTables)
        _buildLeaveTypesSection(leaveTypes, isMobile),
        const SizedBox(height: 20),

        // Section 2: Employee Overrides
        overridesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D8A4E))),
          error: (e, _) => Text('Error loading overrides: $e'),
          data: (overrides) => _buildEmployeeOverridesSection(overrides, employees, leaveTypes, isMobile),
        ),
      ],
    );
  }

  Widget _buildLeaveTypesSection(List<LeaveType> leaveTypes, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Types',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Types shown on employee requests.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8A4E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => _showAddLeaveTypeDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Render Cards list instead of overflowing DataTables
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaveTypes.length,
            itemBuilder: (context, index) {
              final lt = leaveTypes[index];
              return _buildLeaveTypeCard(lt);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveTypeCard(LeaveType lt) {
    final color = _parseHexColor(lt.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _showEditColorDialog(context, lt),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lt.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: lt.isActive,
                  activeTrackColor: const Color(0xFF0D8A4E),
                  onChanged: (val) async {
                    final updated = lt.copyWith(isActive: val);
                    await ref.read(leaveRepositoryProvider).updateLeaveType(updated);
                    ref.invalidate(leaveTypesProvider);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Annual: ${lt.annualAllocation.toStringAsFixed(0)} days/yr',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: Text(
                  'Carry Fwd: ${lt.carryForward}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.palette_outlined, size: 18, color: color),
                tooltip: 'Edit Color',
                onPressed: () => _showEditColorDialog(context, lt),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                tooltip: 'Delete',
                onPressed: () async {
                  await ref.read(leaveRepositoryProvider).deleteLeaveType(lt.id);
                  ref.invalidate(leaveTypesProvider);
                },
              ),
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
    String selectedHex = '#0D8A4E';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add New Leave Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Leave Type Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(hintText: 'e.g. Sick Leave, Vacation', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(hintText: 'Short description...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Allocation (Days)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: allocCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Carry Forward', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: carryForward,
                                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                items: ['Not allowed', 'Up to 3 days', 'Up to 5 days', 'Up to 10 days', 'Unlimited']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 11))))
                                    .toList(),
                                onChanged: (v) => setDialogState(() => carryForward = v ?? carryForward),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Calendar Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    _buildColorPalettePicker(selectedHex, (newHex) {
                      setDialogState(() => selectedHex = newHex);
                    }),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Status', style: TextStyle(fontSize: 13)),
                      value: isActive,
                      activeTrackColor: const Color(0xFF0D8A4E),
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
                child: const Text('Save Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Color: ${leaveType.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select color for calendar & badges:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
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
                child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildColorPalettePicker(String currentHex, Function(String) onSelectHex) {
    final colors = [
      {'name': 'Green', 'hex': '#0D8A4E'},
      {'name': 'Indigo', 'hex': '#6366F1'},
      {'name': 'Teal', 'hex': '#14B8A6'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Purple', 'hex': '#8B5CF6'},
      {'name': 'Rose', 'hex': '#F43F5E'},
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Orange', 'hex': '#F97316'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        final hex = c['hex']!;
        final isSelected = hex.toLowerCase() == currentHex.toLowerCase();
        final color = _parseHexColor(hex);

        return InkWell(
          onTap: () => onSelectHex(hex),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(c['name']!, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmployeeOverridesSection(
    List<Map<String, dynamic>> overrides,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee Overrides',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Per-employee exceptions to standard defaults.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (overrides.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D8A4E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddOverrideDialog(context, employees, leaveTypes),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Override', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Rich Empty State for Overrides
          if (overrides.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D8A4E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 32,
                      color: Color(0xFF0D8A4E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No Employee Overrides Defined',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add per-employee exceptions to standard leave allocations (e.g. extra sick days).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D8A4E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddOverrideDialog(context, employees, leaveTypes),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Employee Override', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: overrides.length,
              separatorBuilder: (ctx, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ov = overrides[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          _getInitials(ov['employee_name'] as String? ?? 'EM'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ov['employee_name']} (${ov['employee_custom_id']})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${ov['leave_type']}: ${ov['override_days']} days allowed',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                        onPressed: () async {
                          final id = ov['id'];
                          if (id is int) {
                            await ref.read(leaveRepositoryProvider).deleteEmployeeOverride(id);
                            ref.invalidate(employeeOverridesProvider);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Employee Override', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employee', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Employee>(
                      initialValue: selectedEmp,
                      isExpanded: true,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      items: employees
                          .map((e) => DropdownMenuItem(value: e, child: Text('${e.fullName} (${e.employeeId})', overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedEmp = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<LeaveType>(
                      initialValue: selectedType,
                      isExpanded: true,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      items: leaveTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.name, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v),
                    ),
                    const SizedBox(height: 12),
                    const Text('Override Days Allowed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
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
                child: const Text('Save Override', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        initialValue: value,
        isExpanded: true,
        isDense: true,
        hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 12)) : null,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
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
    await _showSuperAdminApprovalDialog(req);
  }

  Future<void> _showSuperAdminApprovalDialog(LeaveRequest req) async {
    final currentEmp = ref.read(currentEmployeeProvider);
    final adminName = currentEmp?.fullName ?? 'Admin';
    final employees = ref.read(employeesProvider).value ?? [];
    final empMatch = employees.firstWhere(
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
        department: '',
        designation: '',
        employmentType: '',
        joiningDate: '',
        status: '',
        leaveType: 'As Needed',
      ),
    );

    final employeePolicy = empMatch.leavePolicy;

    double availableQuota = 0.0;
    if (employeePolicy == 'Manual Allocation') {
      final requestLeaveType = req.leaveType.startsWith('Permission') ? 'Permission' : req.leaveType;
      final balance = await ref.read(leaveRepositoryProvider).getLeaveBalance(req.employeeId, requestLeaveType);
      availableQuota = balance.availableLeaves;
    }

    double paidDaysRec = req.numDays;
    double lopDaysRec = 0.0;
    String defaultMode = 'as_calculated';

    if (employeePolicy == 'As Needed') {
      paidDaysRec = req.numDays;
      lopDaysRec = 0.0;
      defaultMode = 'as_calculated';
    } else if (employeePolicy == 'No Leave') {
      paidDaysRec = 0.0;
      lopDaysRec = req.numDays;
      defaultMode = 'all_lop';
    } else {
      paidDaysRec = req.numDays <= availableQuota ? req.numDays : availableQuota;
      lopDaysRec = req.numDays > availableQuota ? req.numDays - availableQuota : 0.0;
      defaultMode = 'as_calculated';
    }

    String selectedMode = defaultMode;
    final reasonController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Approve Leave Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    _buildApprovalDetailRow('Employee', req.employeeName),
                    _buildApprovalDetailRow('Leave Type', req.leaveType),
                    _buildApprovalDetailRow('Requested', '${req.numDays % 1 == 0 ? req.numDays.toInt() : req.numDays} Days (${req.fromDate} to ${req.toDate})'),
                    _buildApprovalDetailRow('Employee Policy', employeePolicy),
                    if (employeePolicy == 'Manual Allocation')
                      _buildApprovalDetailRow('Available Quota', '${availableQuota % 1 == 0 ? availableQuota.toInt() : availableQuota} Days'),

                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('System Calculation / Recommendation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          if (employeePolicy == 'As Needed')
                            Text('• ${req.numDays % 1 == 0 ? req.numDays.toInt() : req.numDays} Days → Paid Leave (As Needed Policy)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D8A4E)))
                          else if (employeePolicy == 'No Leave')
                            Text('• ${req.numDays % 1 == 0 ? req.numDays.toInt() : req.numDays} Days → Potential LOP (No Leave Policy)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706)))
                          else
                            Text(
                              '• ${paidDaysRec % 1 == 0 ? paidDaysRec.toInt() : paidDaysRec} Days → Paid Leave\n'
                              '${lopDaysRec > 0 ? "• ${lopDaysRec % 1 == 0 ? lopDaysRec.toInt() : lopDaysRec} Days → Potential LOP" : ""}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lopDaysRec > 0 ? const Color(0xFFD97706) : const Color(0xFF0D8A4E)),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text('Super Admin Decision:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),

                    if (employeePolicy == 'As Needed') ...[
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Approve all as Paid Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'as_calculated',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                    ] else if (employeePolicy == 'No Leave') ...[
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Approve as LOP (Potential LOP)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'all_lop',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Approve all as Paid Leave (Super Admin Override)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'all_paid',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                    ] else ...[
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Approve as calculated (${paidDaysRec % 1 == 0 ? paidDaysRec.toInt() : paidDaysRec} Paid, ${lopDaysRec % 1 == 0 ? lopDaysRec.toInt() : lopDaysRec} LOP)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'as_calculated',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Approve all as Paid Leave (Super Admin Override)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'all_paid',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Approve all as LOP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: 'all_lop',
                        groupValue: selectedMode,
                        activeColor: const Color(0xFF0D8A4E),
                        onChanged: (v) => setDialogState(() => selectedMode = v!),
                      ),
                    ],

                    const SizedBox(height: 10),
                    const Text('Reason / Note:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter reason (e.g. Emergency situation...)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleDenyRequest(req);
                },
                child: const Text('Reject'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8A4E),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(leaveRepositoryProvider).approveLeaveRequest(
                      req.id,
                      adminName,
                      approvalMode: selectedMode,
                      overrideReason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                    );
                    ref.invalidate(allLeaveRequestsProvider);
                    ref.invalidate(leaveRequestsProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Leave request for ${req.employeeName} approved successfully.'),
                          backgroundColor: const Color(0xFF0D8A4E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error approving request: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildApprovalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDenyRequest(LeaveRequest req) async {
    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final adminName = currentEmp?.fullName ?? 'Admin';
      await ref.read(leaveRepositoryProvider).denyLeaveRequest(req.id, adminName);
      ref.invalidate(allLeaveRequestsProvider);
      ref.invalidate(leaveRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request for ${req.employeeName} denied.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error denying request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
