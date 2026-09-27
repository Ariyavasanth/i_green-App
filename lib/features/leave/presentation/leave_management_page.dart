import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/leave_request.dart';
import '../domain/leave_type.dart';
import '../domain/leave_overlap_validator.dart';
import '../domain/holiday.dart';
import '../providers/leave_providers.dart';
import 'dialogs/admin_leave_review_dialog.dart';

enum LeaveTab { dashboard, requests, calendar, settings }

enum SettingsSubTab { leaveTypes, holidays }

class LeaveManagementPage extends ConsumerStatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  ConsumerState<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends ConsumerState<LeaveManagementPage> {
  LeaveTab _activeTab = LeaveTab.dashboard;
  SettingsSubTab _activeSettingsSubTab = SettingsSubTab.leaveTypes;
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

    final allRequests = allRequestsAsync.value ?? [];
    final pendingRequestsCount = allRequests.where((r) => r.status == 'Pending').length;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0D8A4E))),
        error: (err, stack) => Center(
          child: SelectableText('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (employees) {
          final leaveTypes = leaveTypesAsync.value ?? [];

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFF0D8A4E),
                          onRefresh: () async {
                            ref.invalidate(allLeaveRequestsProvider);
                            ref.invalidate(employeesProvider);
                            ref.invalidate(leaveTypesProvider);
                            ref.invalidate(currentEmployeeProvider);
                            await Future.delayed(const Duration(milliseconds: 500));
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              left: isMobile ? 12.0 : 24.0,
                              right: isMobile ? 12.0 : 24.0,
                              top: isMobile ? 12.0 : 24.0,
                              bottom: 80.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Header: Only show on desktop (!isMobile)
                                if (!isMobile) ...[
                                  _buildTopHeader(context, employees, leaveTypes, currentEmp, isMobile),
                                  const SizedBox(height: 20),
                                ],


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
                                    LeaveTab.settings => _buildSettingsTab(employees, leaveTypes, isMobile),
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildBottomNavBar(pendingRequestsCount, isMobile),

                    ],
                  ),
                  if (isMobile)
                    Positioned(
                      right: 16,
                      bottom: 72,
                      child: FloatingActionButton(
                        shape: const CircleBorder(),
                        elevation: 4,
                        backgroundColor: const Color(0xFF9CC70A),
                        onPressed: () {
                          if (_activeTab == LeaveTab.settings) {
                            switch (_activeSettingsSubTab) {
                              case SettingsSubTab.leaveTypes:
                                _showAddLeaveTypeDialog(context);
                                break;
                              case SettingsSubTab.holidays:
                                _showAddHolidayDialog(context);
                                break;
                            }
                          } else {
                            _showApplyLeaveDialog(context, employees, leaveTypes, currentEmp);
                          }
                        },
                        child: const Icon(Icons.add, color: Color(0xFF414A51), size: 28),
                      ),
                    ),
                ],
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
    if (_activeTab == LeaveTab.settings) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSettingsSubTabSelector(isMobile: false),
          _buildSettingsActionButton(context, employees, leaveTypes),
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF414A51)),
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
            backgroundColor: const Color(0xFF9CC70A),
            foregroundColor: const Color(0xFF414A51),
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

    String durationOption = 'full_day';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isSingleDay = fromDate.year == toDate.year &&
              fromDate.month == toDate.month &&
              fromDate.day == toDate.day;

          if (!isSingleDay) {
            durationOption = 'full_day';
          }
          final isHalfDay = isSingleDay && durationOption != 'full_day';
          final halfDayPeriod = isHalfDay ? durationOption : null;

          final days = toDate.difference(fromDate).inDays + 1;
          final calcDays = isHalfDay ? 0.5 : (days > 0 ? days : 1).toDouble();
          final permHours = calculatePermissionHours(fromTime, toTime);

          final allRequests = ref.watch(allLeaveRequestsProvider).value ?? [];
          final empRequests = selectedEmployee != null
              ? allRequests.where((r) => r.employeeId == selectedEmployee!.id).toList()
              : <LeaveRequest>[];

          final fromStr = DateFormat('dd-MM-yyyy').format(fromDate);
          final toStr = DateFormat('dd-MM-yyyy').format(toDate);

          final overlapResult = selectedEmployee != null
              ? LeaveOverlapValidator.checkOverlap(
                  newFromDate: fromStr,
                  newToDate: toStr,
                  isHalfDay: isHalfDay,
                  halfDayPeriod: halfDayPeriod,
                  existingRequests: empRequests,
                  employeeId: selectedEmployee!.id,
                )
              : const LeaveOverlapResult(hasOverlap: false);

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

                    // Leave Type Dropdown
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
                    // Leave Duration Radio Tiles (Only for Single Day)
                    if (isSingleDay) ...[
                      const SizedBox(height: 14),
                      const Text('Leave Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF9CC70A),
                              title: const Text('Full Day', style: TextStyle(fontSize: 12, color: Color(0xFF414A51))),
                              value: 'full_day',
                              groupValue: durationOption,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => durationOption = val);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF9CC70A),
                              title: const Text('First Half', style: TextStyle(fontSize: 12, color: Color(0xFF414A51))),
                              value: 'first_half',
                              groupValue: durationOption,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    durationOption = val;
                                    toDate = fromDate;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF9CC70A),
                              title: const Text('Second Half', style: TextStyle(fontSize: 12, color: Color(0xFF414A51))),
                              value: 'second_half',
                              groupValue: durationOption,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    durationOption = val;
                                    toDate = fromDate;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Shift breakdown banner for half-day
                      if (durationOption == 'first_half') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('First Half Leave: 9:00 AM – 1:30 PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              SizedBox(height: 2),
                              Text('Remaining Work: 1:30 PM – 6:00 PM', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              SizedBox(height: 2),
                              Text('Duration: 0.5 Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A))),
                            ],
                          ),
                        ),
                      ] else if (durationOption == 'second_half') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Second Half Leave: 1:30 PM – 6:00 PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              SizedBox(height: 2),
                              Text('Remaining Work: 9:00 AM – 1:30 PM', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              SizedBox(height: 2),
                              Text('Duration: 0.5 Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A))),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),
                    Text(
                      'Total Duration: ${calcDays.toStringAsFixed(1)} day(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CC70A)),
                    ),
                    const SizedBox(height: 14),

                    // Real-Time Overlap Conflict Banner
                    if (overlapResult.hasOverlap) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '⚠️ Leave Already Requested',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    overlapResult.message ?? 'An overlapping leave request already exists for the selected date/period.',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

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
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: overlapResult.hasOverlap
                    ? null
                    : () async {
                        if (selectedEmployee == null) return;
                        if (selectedLeaveType == null) return;

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
                          numDays: calcDays,
                          reason: reasonController.text.trim(),
                          status: 'Pending',
                          createdAt: DateTime.now().toIso8601String(),
                          approvedDates: [],
                          lopDates: [],
                          isEmergency: isEmergency,
                          isHalfDay: isHalfDay,
                          halfDayPeriod: halfDayPeriod,
                        );

                        try {
                          await ref.read(leaveRepositoryProvider).submitLeaveRequest(newRequest);
                          ref.invalidate(allLeaveRequestsProvider);
                          ref.invalidate(leaveRequestsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit: $e'),
                                backgroundColor: const Color(0xFFC62828),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. BOTTOM DOCKED NAVIGATION BAR (64px Icon-on-Top & Label-Underneath Bar)
  // ---------------------------------------------------------------------------
  Widget _buildBottomNavBar(int pendingCount, bool isMobile) {
    Widget buildBadgeIcon(IconData iconData, bool isActive) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(iconData, size: 22, color: isActive ? const Color(0xFF9CC70A) : const Color(0xFF64748B)),
          if (pendingCount > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _activeTab.index,
        onTap: (index) => setState(() => _activeTab = LeaveTab.values[index]),
        selectedItemColor: const Color(0xFF9CC70A),
        unselectedItemColor: const Color(0xFF64748B),
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            activeIcon: Icon(Icons.dashboard, size: 22),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: buildBadgeIcon(Icons.assignment_outlined, false),
            activeIcon: buildBadgeIcon(Icons.assignment, true),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined, size: 22),
            activeIcon: Icon(Icons.calendar_today, size: 22),
            label: 'Calendar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 22),
            activeIcon: Icon(Icons.settings, size: 22),
            label: 'Settings',
          ),
        ],
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
    String dateSubtitle;
    if (req.leaveType.toLowerCase().startsWith('permission') || req.fromDate == req.toDate) {
      dateSubtitle = '${req.leaveType} · ${_formatDateDisplay(req.fromDate)}';
    } else {
      dateSubtitle = '${req.leaveType} · ${_formatDateDisplay(req.fromDate)} — ${_formatDateDisplay(req.toDate)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                      dateSubtitle,
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

    String dateDisplay;
    if (req.leaveType.toLowerCase().startsWith('permission') || req.fromDate == req.toDate) {
      dateDisplay = _formatDateDisplay(req.fromDate);
    } else {
      dateDisplay = '${_formatDateDisplay(req.fromDate)} — ${_formatDateDisplay(req.toDate)} · ${_formatDurationDisplay(req)}';
    }

    final primaryTitle = emp.designation.isNotEmpty ? emp.designation : emp.department;
    final empSub = req.employeeCustomId.isNotEmpty
        ? '${req.employeeCustomId} · $primaryTitle'
        : primaryTitle;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
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
                radius: 16,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  _getInitials(req.employeeName),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      empSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(req.status),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),

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
                  dateDisplay,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: "${req.reason}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
            ),
          ],
          const SizedBox(height: 6),

          // Full-width Bottom Action Row: Audit History on bottom-left, Actions / Change Decision on bottom-right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () => _showAuditHistoryDialog(req),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'Audit history',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              if (isPending)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _handleDenyRequest(req),
                      child: const Text('Deny', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFF0D8A4E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleApproveRequest(req),
                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _showSuperAdminApprovalDialog(req),
                  icon: const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF0D8A4E)),
                  label: const Text('Change Decision', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D8A4E))),
                ),
            ],
          ),
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
        return Consumer(
          builder: (context, ref, child) {
            final logsAsync = ref.watch(leaveAuditLogsProvider(req.id));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Audit History - ${req.employeeName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: logsAsync.when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0D8A4E))),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading audit logs: $e', style: const TextStyle(color: Colors.red)),
                  ),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No audit logs available for this request.', style: TextStyle(color: Color(0xFF64748B))),
                      );
                    }
                    return SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: logs.length,
                        separatorBuilder: (ctx, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFF1F5F9),
                              child: Icon(Icons.history, size: 16, color: Color(0xFF64748B)),
                            ),
                            title: Text(
                              log['action'] as String? ?? 'Action',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            subtitle: Text(
                              'By: ${log['performed_by'] ?? 'System'} · ${log['timestamp'] ?? ''}\n${log['details'] ?? ''}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
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
    final holidaysAsync = ref.watch(holidaysProvider);
    final holidayListAsync = ref.watch(holidayListProvider);
    final holidays = holidaysAsync.value ?? [];
    final holidayModels = holidayListAsync.value ?? [];

    final filteredRequests = allRequests.where((req) {
      if (_filterEmployeeId != null && req.employeeId != _filterEmployeeId) return false;
      return true;
    }).toList();

    final calendarView = _buildCalendarGrid(filteredRequests, employees, leaveTypes, holidays, holidayModels, isMobile);
    final sidePanel = _buildCalendarDayDetailPanel(filteredRequests, employees, leaveTypes, holidayModels);

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
    List<String> holidays,
    List<Holiday> holidayModels,
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
              
              // Holiday check
              bool isHoliday = false;
              Holiday? holidayMatch;
              for (final h in holidayModels) {
                final parsed = _parseDate(h.date);
                if (h.date.trim() == cellDateStr || (parsed != null && parsed.year == cellDate.year && parsed.month == cellDate.month && parsed.day == cellDate.day)) {
                  isHoliday = true;
                  holidayMatch = h;
                  break;
                }
              }

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

              final Color cellBg;
              final Color borderColor;
              if (isSelected) {
                cellBg = const Color(0xFFF0FDF4);
                borderColor = const Color(0xFF9CC70A);
              } else if (isToday) {
                cellBg = const Color(0xFFF8FAFC);
                borderColor = const Color(0xFF9CC70A);
              } else if (isHoliday) {
                cellBg = const Color(0xFFFAF5FF);
                borderColor = const Color(0xFFE9D5FF);
              } else {
                cellBg = Colors.white;
                borderColor = const Color(0xFFE2E8F0);
              }

              return InkWell(
                onTap: () => setState(() => _selectedCalendarDate = cellDate),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cellBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected || isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF9CC70A) : (isHoliday ? const Color(0xFF7C3AED) : const Color(0xFF334155)),
                            ),
                          ),
                          if (isHoliday)
                            const Icon(Icons.celebration, size: 10, color: Color(0xFF7C3AED)),
                        ],
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
                                    color: isPend ? const Color(0xFFF59E0B) : const Color(0xFF9CC70A),
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
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF9CC70A), shape: BoxShape.circle)),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('Holiday (Paid Day)', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
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
    List<Holiday> holidayModels,
  ) {
    final cellDateStr = '${_selectedCalendarDate.day.toString().padLeft(2, '0')}-${_selectedCalendarDate.month.toString().padLeft(2, '0')}-${_selectedCalendarDate.year}';
    final formattedDateTitle = DateFormat('MMM d, yyyy').format(_selectedCalendarDate);

    // Check if selected date is a holiday
    Holiday? holidayMatch;
    for (final h in holidayModels) {
      final parsed = _parseDate(h.date);
      if (h.date.trim() == cellDateStr || (parsed != null && parsed.year == _selectedCalendarDate.year && parsed.month == _selectedCalendarDate.month && parsed.day == _selectedCalendarDate.day)) {
        holidayMatch = h;
        break;
      }
    }

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
          const SizedBox(height: 6),

          // Holiday Banner if date is a holiday
          if (holidayMatch != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.celebration, size: 18, color: Color(0xFF7C3AED)),
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
                              holidayMatch.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF581C87)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Paid Day', style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          holidayMatch.type,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                        ),
                        if (holidayMatch.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            holidayMatch.description,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B21A8)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          Text(
            '${dayRequests.length} employee${dayRequests.length == 1 ? '' : 's'} on leave',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (dayRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  holidayMatch != null ? 'All employees are on paid holiday.' : 'No employees on leave for this date.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
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
  // 6. SETTINGS & HOLIDAYS TAB (OPTION B SUB-TABS)
  // ---------------------------------------------------------------------------
  Widget _buildSettingsTab(List<Employee> employees, List<LeaveType> leaveTypes, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          _buildSettingsSubTabSelector(isMobile: true),
          const SizedBox(height: 16),
        ],
        switch (_activeSettingsSubTab) {
          SettingsSubTab.leaveTypes => _buildLeaveTypesSection(leaveTypes, isMobile),
          SettingsSubTab.holidays => _buildHolidaysSection(isMobile),
        },
      ],
    );
  }

  Widget _buildSettingsSubTabSelector({required bool isMobile}) {
    final tabs = [
      (SettingsSubTab.leaveTypes, 'Leave Types', Icons.category_outlined),
      (SettingsSubTab.holidays, 'Holidays', Icons.celebration_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: tabs.map((t) {
          final isSelected = _activeSettingsSubTab == t.$1;
          final item = InkWell(
            onTap: () => setState(() => _activeSettingsSubTab = t.$1),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    t.$3,
                    size: 16,
                    color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF414A51) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );

          return isMobile ? Expanded(child: item) : item;
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsActionButton(
    BuildContext context,
    List<Employee> employees,
    List<LeaveType> leaveTypes,
  ) {
    if (_activeSettingsSubTab == SettingsSubTab.holidays) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF414A51),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showBulkAddHolidaysDialog(context),
            icon: const Icon(Icons.playlist_add, size: 18, color: Color(0xFF7C3AED)),
            label: const Text('Bulk Add Holidays', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: const Color(0xFF414A51),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _showAddHolidayDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ Add Holiday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: const Color(0xFF414A51),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      onPressed: () => _showAddLeaveTypeDialog(context),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('+ Add Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  // --- Holidays Section ---
  Widget _buildHolidaysSection(bool isMobile) {
    final holidayListAsync = ref.watch(holidayListProvider);

    return holidayListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
      error: (e, _) => Center(child: Text('Error loading holidays: $e')),
      data: (holidays) {
        if (holidays.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_outlined,
                    size: 36,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Holidays Added',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add company and national holidays. Holidays are treated as paid days and reflected across all calendars.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: const Color(0xFF414A51),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => _showAddHolidayDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Holiday', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7C3AED),
                        side: const BorderSide(color: Color(0xFF7C3AED)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showBulkAddHolidaysDialog(context),
                      icon: const Icon(Icons.playlist_add, size: 16),
                      label: const Text('Bulk Add Preset Holidays', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Company Holidays (${holidays.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showBulkAddHolidaysDialog(context),
                    icon: const Icon(Icons.playlist_add, size: 16, color: Color(0xFF7C3AED)),
                    label: const Text('Bulk Add', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: holidays.length,
              itemBuilder: (context, index) {
                final h = holidays[index];
                return _buildHolidayCard(h);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHolidayCard(Holiday h) {
    final parsedDate = _parseDate(h.date);
    final dateDisplay = parsedDate != null ? DateFormat('dd MMM yyyy (EEEE)').format(parsedDate) : h.date;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.celebration, size: 16, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      dateDisplay,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  h.type,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: h.isActive,
                  activeTrackColor: const Color(0xFF9CC70A),
                  onChanged: (val) async {
                    final updated = h.copyWith(isActive: val);
                    await ref.read(leaveRepositoryProvider).updateHoliday(updated);
                    ref.invalidate(holidayListProvider);
                    ref.invalidate(holidaysProvider);
                  },
                ),
              ),
            ],
          ),
          if (h.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              h.description,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
          const Divider(height: 14, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _showAddHolidayDialog(context, h),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Delete Holiday'),
                      content: Text('Are you sure you want to delete "${h.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(leaveRepositoryProvider).deleteHoliday(h.id);
                    ref.invalidate(holidayListProvider);
                    ref.invalidate(holidaysProvider);
                  }
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddHolidayDialog(BuildContext context, [Holiday? existing]) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing != null ? (_parseDate(existing.date) ?? DateTime.now()) : DateTime.now();
    String selectedType = existing?.type ?? 'National Holiday';
    bool isActive = existing?.isActive ?? true;

    final holidayTypes = [
      'National Holiday',
      'Festival',
      'Company Holiday',
      'Optional Holiday',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              existing != null ? 'Edit Holiday' : 'Add Holiday',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Holiday Name / Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Diwali, Gandhi Jayanti',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Holiday Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
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
                              DateFormat('dd-MM-yyyy (EEEE)').format(selectedDate),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                            ),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Holiday Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: holidayTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v ?? selectedType),
                    ),
                    const SizedBox(height: 12),
                    const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Brief note or description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Holiday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      value: isActive,
                      activeTrackColor: const Color(0xFF9CC70A),
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9CC70A), foregroundColor: const Color(0xFF414A51)),
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
                  final holiday = Holiday(
                    id: existing?.id ?? '',
                    title: titleCtrl.text.trim(),
                    date: dateStr,
                    type: selectedType,
                    description: descCtrl.text.trim(),
                    year: selectedDate.year,
                    isActive: isActive,
                  );

                  if (existing != null) {
                    await ref.read(leaveRepositoryProvider).updateHoliday(holiday);
                  } else {
                    await ref.read(leaveRepositoryProvider).addHoliday(holiday);
                  }
                  ref.invalidate(holidayListProvider);
                  ref.invalidate(holidaysProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing != null ? 'Update Holiday' : 'Save Holiday', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeaveTypesSection(List<LeaveType> leaveTypes, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave Types',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (isMobile)
                TextButton.icon(
                  onPressed: () => _showAddLeaveTypeDialog(context),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF414A51)),
                  label: const Text('Add Leave Type', style: TextStyle(color: Color(0xFF414A51), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
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
    );
  }

  Widget _buildLeaveTypeCard(LeaveType lt) {
    final color = _parseHexColor(lt.colorHex);
    final daysStr = '${lt.annualAllocation.toStringAsFixed(0)} days / year';
    final carryStr = 'Carry over: ${lt.carryForward}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Colored Dot, Leave Name, Toggle Switch
          Row(
            children: [
              InkWell(
                onTap: () => _showEditColorDialog(context, lt),
                child: Container(
                  width: 12,
                  height: 12,
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
                scale: 0.8,
                child: Switch(
                  value: lt.isActive,
                  activeTrackColor: const Color(0xFF9CC70A),
                  onChanged: (val) async {
                    final updated = lt.copyWith(isActive: val);
                    await ref.read(leaveRepositoryProvider).updateLeaveType(updated);
                    ref.invalidate(leaveTypesProvider);
                  },
                ),
              ),
            ],
          ),

          // Middle Row: Display rules cleanly
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              '$daysStr  •  $carryStr',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),

          // Bottom-Right Actions: Edit & Delete Icons in lighter gray
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _showEditColorDialog(context, lt),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.palette_outlined, size: 18, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () async {
                  await ref.read(leaveRepositoryProvider).deleteLeaveType(lt.id);
                  ref.invalidate(leaveTypesProvider);
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                ),
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

  void _showBulkAddHolidaysDialog(BuildContext context) {
    int selectedYear = DateTime.now().year;
    int tabIndex = 0; // 0: Preset Holidays, 1: Custom Multi-Row

    List<Map<String, dynamic>> generatePresetList(int yr) {
      return [
        {'title': "New Year's Day", 'date': '01-01-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Pongal / Makar Sankranti', 'date': '14-01-$yr', 'type': 'Festival', 'selected': true},
        {'title': 'Thiruvalluvar Day / Mattu Pongal', 'date': '15-01-$yr', 'type': 'Festival', 'selected': true},
        {'title': 'Republic Day', 'date': '26-01-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Maha Shivaratri', 'date': '15-02-$yr', 'type': 'Festival', 'selected': false},
        {'title': 'Holi', 'date': '04-03-$yr', 'type': 'Festival', 'selected': false},
        {'title': 'Good Friday', 'date': '03-04-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Tamil New Year / Ambedkar Jayanti', 'date': '14-04-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'May Day (Labour Day)', 'date': '01-05-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Bakrid / Eid al-Adha', 'date': '27-05-$yr', 'type': 'Festival', 'selected': true},
        {'title': 'Muharram', 'date': '26-06-$yr', 'type': 'Festival', 'selected': false},
        {'title': 'Independence Day', 'date': '15-08-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Krishna Jayanti / Janmashtami', 'date': '04-09-$yr', 'type': 'Festival', 'selected': false},
        {'title': 'Milad-un-Nabi', 'date': '25-09-$yr', 'type': 'Festival', 'selected': false},
        {'title': 'Gandhi Jayanti', 'date': '02-10-$yr', 'type': 'National Holiday', 'selected': true},
        {'title': 'Ayudha Puja / Vijayadashami', 'date': '20-10-$yr', 'type': 'Festival', 'selected': true},
        {'title': 'Deepavali (Diwali)', 'date': '08-11-$yr', 'type': 'Festival', 'selected': true},
        {'title': 'Christmas', 'date': '25-12-$yr', 'type': 'National Holiday', 'selected': true},
      ];
    }

    var presetHolidays = generatePresetList(selectedYear);

    final List<Map<String, dynamic>> customRows = [
      {'ctrl': TextEditingController(text: 'Company Annual Day'), 'date': DateTime(selectedYear, 1, 15), 'type': 'Company Holiday'},
      {'ctrl': TextEditingController(text: 'Founder\'s Day'), 'date': DateTime(selectedYear, 5, 20), 'type': 'Company Holiday'},
    ];

    const holidayTypes = [
      'National Holiday',
      'Festival',
      'Company Holiday',
      'Optional Holiday',
      'Restricted Holiday',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedPresetCount = presetHolidays.where((h) => h['selected'] == true).length;
          final allSelected = selectedPresetCount == presetHolidays.length;

          final screenSize = MediaQuery.sizeOf(ctx);
          final dialogWidth = math.min(screenSize.width - 24, 520.0);
          final dialogHeight = math.min(screenSize.height * 0.72, 480.0);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_add, color: Color(0xFF7C3AED), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bulk Add Holidays',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedYear,
                      isDense: true,
                      items: [2024, 2025, 2026, 2027, 2028, 2029, 2030].map((y) {
                        return DropdownMenuItem(
                          value: y,
                          child: Text('$y', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (yr) {
                        if (yr != null) {
                          setDialogState(() {
                            selectedYear = yr;
                            presetHolidays = generatePresetList(yr);
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Switcher
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => tabIndex = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              decoration: BoxDecoration(
                                color: tabIndex == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: tabIndex == 0
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Presets ($selectedPresetCount)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: tabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: tabIndex == 0 ? const Color(0xFF414A51) : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => tabIndex = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              decoration: BoxDecoration(
                                color: tabIndex == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: tabIndex == 1
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Custom (${customRows.length})',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: tabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: tabIndex == 1 ? const Color(0xFF414A51) : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 0: Preset List
                  if (tabIndex == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select holidays to add:',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              final newVal = !allSelected;
                              for (var h in presetHolidays) {
                                h['selected'] = newVal;
                              }
                            });
                          },
                          child: Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        itemCount: presetHolidays.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, i) {
                          final h = presetHolidays[i];
                          final isSelected = h['selected'] == true;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF9CC70A),
                            checkColor: const Color(0xFF414A51),
                            value: isSelected,
                            onChanged: (v) => setDialogState(() => h['selected'] = v ?? false),
                            title: Text(h['title'] as String, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            subtitle: Text('Date: ${h['date']} • ${h['type']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // Tab 1: Custom Multi-Row Entry
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enter holiday details:',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              customRows.add({
                                'ctrl': TextEditingController(),
                                'date': DateTime(selectedYear, 1, 1),
                                'type': 'Company Holiday',
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 14, color: Color(0xFF414A51)),
                          label: const Text('Add Row', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        itemCount: customRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final row = customRows[i];
                          final ctrl = row['ctrl'] as TextEditingController;
                          final date = row['date'] as DateTime;
                          final type = row['type'] as String;

                          return Container(
                            padding: const EdgeInsets.all(8),
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
                                    // Date Picker
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: ctx,
                                          initialDate: date,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) {
                                          setDialogState(() => row['date'] = picked);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.calendar_today, size: 12, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd-MM-yyyy').format(date),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Type Dropdown
                                    Expanded(
                                      child: Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: type,
                                            isDense: true,
                                            isExpanded: true,
                                            items: holidayTypes.map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                                            )).toList(),
                                            onChanged: (v) => setDialogState(() => row['type'] = v ?? type),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (customRows.length > 1) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                        onPressed: () => setDialogState(() => customRows.removeAt(i)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Title Field
                                SizedBox(
                                  height: 34,
                                  child: TextField(
                                    controller: ctrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Holiday Name / Title',
                                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final List<Holiday> holidaysToAdd = [];

                  if (tabIndex == 0) {
                    for (final item in presetHolidays) {
                      if (item['selected'] == true) {
                        holidaysToAdd.add(
                          Holiday(
                            id: '',
                            title: item['title'] as String,
                            date: item['date'] as String,
                            type: item['type'] as String,
                            description: '${item['title']} - Public Holiday $selectedYear',
                            year: selectedYear,
                            isActive: true,
                          ),
                        );
                      }
                    }
                  } else {
                    for (final row in customRows) {
                      final ctrl = row['ctrl'] as TextEditingController;
                      final t = ctrl.text.trim();
                      if (t.isNotEmpty) {
                        final dt = row['date'] as DateTime;
                        final dateStr = DateFormat('dd-MM-yyyy').format(dt);
                        holidaysToAdd.add(
                          Holiday(
                            id: '',
                            title: t,
                            date: dateStr,
                            type: row['type'] as String,
                            description: '',
                            year: dt.year,
                            isActive: true,
                          ),
                        );
                      }
                    }
                  }

                  if (holidaysToAdd.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No holidays selected or filled to add.')),
                    );
                    return;
                  }

                  await ref.read(leaveRepositoryProvider).addHolidays(holidaysToAdd);
                  ref.invalidate(holidayListProvider);
                  ref.invalidate(holidaysProvider);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully added ${holidaysToAdd.length} holidays for $selectedYear!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                },
                child: Text(
                  tabIndex == 0
                      ? 'Add $selectedPresetCount Holidays'
                      : 'Save All Rows',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
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
    showDialog(
      context: context,
      builder: (ctx) => AdminLeaveReviewDialog(request: req),
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
