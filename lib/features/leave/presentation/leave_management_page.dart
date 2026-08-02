import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/leave_request.dart';
import '../providers/leave_providers.dart';

class LeaveManagementPage extends ConsumerStatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  ConsumerState<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends ConsumerState<LeaveManagementPage> {
  DateTime _focusedMonth = DateTime.now();
  int? _selectedEmployeeFilterId; // null means 'All Employees'

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

  Color? _getCellColor(DateTime cellDate, List<LeaveRequest> requests, {int? filterEmpId}) {
    final dateStr =
        '${cellDate.day.toString().padLeft(2, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.year}';

    for (final req in requests) {
      if (filterEmpId != null && req.employeeId != filterEmpId) continue;

      if (req.status == 'Approved') {
        if (req.approvedDates.contains(dateStr)) {
          return const Color(0xFF2E7D32); // Green
        }
        if (req.lopDates.contains(dateStr)) {
          return const Color(0xFFE53935); // Light Red / Red
        }
      } else if (req.status == 'Pending') {
        final from = _parseDate(req.fromDate);
        final to = _parseDate(req.toDate);
        if (from != null && to != null) {
          final cellNorm = DateTime(cellDate.year, cellDate.month, cellDate.day);
          final fromNorm = DateTime(from.year, from.month, from.day);
          final toNorm = DateTime(to.year, to.month, to.day);
          if ((cellNorm.isAfter(fromNorm) || cellNorm.isAtSameMomentAs(fromNorm)) &&
              (cellNorm.isBefore(toNorm) || cellNorm.isAtSameMomentAs(toNorm))) {
            return const Color(0xFFFBC02D); // Yellow
          }
        }
      }
    }
    return null;
  }

  String? _getCellTooltip(DateTime cellDate, List<LeaveRequest> requests, {int? filterEmpId}) {
    final dateStr =
        '${cellDate.day.toString().padLeft(2, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.year}';

    for (final req in requests) {
      if (filterEmpId != null && req.employeeId != filterEmpId) continue;

      bool match = false;
      String status = '';
      if (req.status == 'Approved') {
        if (req.approvedDates.contains(dateStr)) {
          match = true;
          status = 'Approved';
        } else if (req.lopDates.contains(dateStr)) {
          match = true;
          status = 'Loss of Pay (LOP)';
        }
      } else if (req.status == 'Pending') {
        final from = _parseDate(req.fromDate);
        final to = _parseDate(req.toDate);
        if (from != null && to != null) {
          final cellNorm = DateTime(cellDate.year, cellDate.month, cellDate.day);
          final fromNorm = DateTime(from.year, from.month, from.day);
          final toNorm = DateTime(to.year, to.month, to.day);
          if ((cellNorm.isAfter(fromNorm) || cellNorm.isAtSameMomentAs(fromNorm)) &&
              (cellNorm.isBefore(toNorm) || cellNorm.isAtSameMomentAs(toNorm))) {
            match = true;
            status = 'Pending';
          }
        }
      }

      if (match) {
        return 'Employee: ${req.employeeName}\nID: ${req.employeeCustomId}\nType: ${req.leaveType}\nStatus: $status\nDays: ${req.numDays}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final employeesAsync = ref.watch(employeesProvider);

    return employeesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFEFF3F6),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFFEFF3F6),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              'Error loading employees: $err\n\nStacktrace:\n$stack',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
      data: (_) {
        if (currentEmp == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFEFF3F6),
            body: Center(
              child: Text(
                'No employee profile found (the database has no employees).',
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        final String adminName = currentEmp.fullName;

        return Scaffold(
          backgroundColor: const Color(0xFFEFF3F6),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                const Row(
                  children: [
                    Icon(Icons.calendar_month, size: 24, color: AppColors.active),
                    SizedBox(width: 8),
                    Text(
                      'Leave Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final calendarWidget = _buildCalendarCard();
                    final requestListWidget = _buildLeaveListCard(adminName);

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: calendarWidget),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: requestListWidget),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          calendarWidget,
                          const SizedBox(height: 20),
                          requestListWidget,
                        ],
                      );
                    }
                  },
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard() {
    final leaveAsync = ref.watch(allLeaveRequestsProvider);
    final employeesAsync = ref.watch(employeesProvider);

    return leaveAsync.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => Card(child: Text('Error: $e')),
      data: (allRequests) {
        final filteredRequests = allRequests.where((req) {
          if (_selectedEmployeeFilterId != null) {
            return req.employeeId == _selectedEmployeeFilterId;
          }
          return true;
        }).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Month Navigation and Employee Filter
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isNarrow = headerConstraints.maxWidth < 600;

                  final monthNav = Row(
                    mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppColors.active),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        _monthYearString(_focusedMonth),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppColors.active),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  );

                  final filterDropdown = employeesAsync.maybeWhen(
                    data: (employees) {
                      return SizedBox(
                        width: isNarrow ? double.infinity : 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedEmployeeFilterId,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter Employee',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Employees', style: TextStyle(fontSize: 12)),
                            ),
                            ...employees.map((e) {
                              return DropdownMenuItem<int?>(
                                value: e.id,
                                child: Text(e.fullName, style: const TextStyle(fontSize: 12)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedEmployeeFilterId = val;
                            });
                          },
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        monthNav,
                        const SizedBox(height: 10),
                        filterDropdown,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      monthNav,
                      const Spacer(),
                      filterDropdown,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Calendar Days Labels
              Row(
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 12,
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

              // Grid Rows
              ..._buildCalendarRows(filteredRequests),

              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFF2E7D32), 'Approved'),
                  const SizedBox(width: 16),
                  _buildLegendItem(const Color(0xFFFBC02D), 'Pending'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  List<Widget> _buildCalendarRows(List<LeaveRequest> requests) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sun = 0

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final List<Widget> rows = [];
    int day = 1 - startWeekday;

    while (day <= daysInMonth) {
      final List<Widget> cells = [];
      for (int i = 0; i < 7; i++) {
        if (day < 1 || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 40)));
        } else {
          final dateNorm = DateTime(year, month, day);
          final isToday = dateNorm == todayNorm;

          final leaveColor = _getCellColor(dateNorm, requests, filterEmpId: _selectedEmployeeFilterId);
          final tooltipMsg = _getCellTooltip(dateNorm, requests, filterEmpId: _selectedEmployeeFilterId);

          Widget dayCell = Container(
            height: 40,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: leaveColor ?? (isToday ? AppColors.active : null),
              borderRadius: BorderRadius.circular(6),
              border: isToday && leaveColor == null ? Border.all(color: AppColors.primary, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || leaveColor != null ? FontWeight.bold : FontWeight.w500,
                  color: leaveColor != null
                      ? Colors.white
                      : (isToday ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          );

          if (tooltipMsg != null) {
            dayCell = Tooltip(
              message: tooltipMsg,
              textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: dayCell,
            );
          }

          cells.add(Expanded(child: dayCell));
        }
        day++;
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  Widget _buildLeaveListCard(String adminName) {
    final requestsAsync = ref.watch(allLeaveRequestsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: AppColors.active),
              SizedBox(width: 8),
              Text(
                'Incoming Requests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading requests: $e'),
            data: (allReqs) {
              final list = allReqs.where((req) {
                if (_selectedEmployeeFilterId != null) {
                  return req.employeeId == _selectedEmployeeFilterId;
                }
                return true;
              }).toList();

              if (list.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: const Column(
                    children: [
                      Icon(Icons.event_busy, size: 40, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text(
                        'No requests found',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final req = list[index];
                  return _buildLeaveRequestTile(req, adminName);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestTile(LeaveRequest req, String adminName) {
    Color statusColor;
    IconData statusIcon;

    switch (req.status) {
      case 'Approved':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle;
        break;
      case 'Denied':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFE65100);
        statusIcon = Icons.hourglass_bottom;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: AppColors.active),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${req.fromDate} to ${req.toDate}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      req.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Employee: ${req.employeeName} (${req.employeeCustomId})',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Type: ${req.leaveType}  •  Days: ${req.numDays}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${req.reason}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],

          // Audit logs view button
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 20)),
            onPressed: () => _showAuditHistoryDialog(req.id),
            icon: const Icon(Icons.history, size: 12),
            label: const Text('View Audit History', style: TextStyle(fontSize: 10)),
          ),

          // Admin action buttons
          if (req.status == 'Pending') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFC62828)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _handleDenyRequest(req.id, adminName),
                  child: const Text('Deny', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _handleApproveRequest(req.id, adminName),
                  child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Future<void> _handleApproveRequest(int id, String adminName) async {
    try {
      await ref.read(leaveRepositoryProvider).approveLeaveRequest(id, adminName);
      ref.invalidate(allLeaveRequestsProvider);
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(salaryCalculationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request approved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDenyRequest(int id, String adminName) async {
    try {
      await ref.read(leaveRepositoryProvider).denyLeaveRequest(id, adminName);
      ref.invalidate(allLeaveRequestsProvider);
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(salaryCalculationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request denied.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAuditHistoryDialog(int reqId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final logsAsync = ref.watch(leaveAuditLogsProvider(reqId));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Leave Request Audit History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                height: 300,
                child: logsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const Center(child: Text('No audit logs for this request.'));
                    }
                    return ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, idx) {
                        final log = logs[idx];
                        final rawTime = log['timestamp'] as String? ?? '';
                        String formattedTime = rawTime;
                        try {
                          final parsed = DateTime.parse(rawTime);
                          formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed);
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log['action'] as String? ?? 'Log',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Action By: ${log['performed_by'] ?? 'System'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                log['details'] as String? ?? '',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _monthYearString(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
