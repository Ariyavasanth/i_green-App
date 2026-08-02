import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/leave_request.dart';
import '../providers/leave_providers.dart';

class LeavePage extends ConsumerStatefulWidget {
  const LeavePage({super.key});

  @override
  ConsumerState<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends ConsumerState<LeavePage> {
  DateTime _focusedMonth = DateTime.now();

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

  Color? _getCellColor(DateTime cellDate, List<LeaveRequest> requests) {
    final dateStr =
        '${cellDate.day.toString().padLeft(2, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.year}';

    for (final req in requests) {
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

  String? _getCellTooltip(DateTime cellDate, List<LeaveRequest> requests) {
    final dateStr =
        '${cellDate.day.toString().padLeft(2, '0')}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.year}';

    for (final req in requests) {
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

        return Scaffold(
          backgroundColor: const Color(0xFFEFF3F6),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 24, color: AppColors.active),
                    const SizedBox(width: 8),
                    const Text(
                      'Leave Requests',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (currentEmp.leaveType != 'No Leave')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.active,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showNewLeaveDialog(currentEmp),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          '+ New Leave',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Leave balance description
                _buildEmployeeBalanceCard(currentEmp),
                const SizedBox(height: 20),

                // Content Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    final calendarWidget = _buildCalendarCard(currentEmp.id);
                    final requestListWidget = _buildLeaveListCard(currentEmp.id);

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

                const SizedBox(height: 24),
                // Salary calculation section
                _buildSalaryLopCalculationCard(currentEmp.id),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeBalanceCard(Employee emp) {
    final type = emp.leaveType;
    String message = '';
    Color bgColor = const Color(0xFFE8F5E9); // Light green
    Color textColor = const Color(0xFF2E7D32); // Dark green
    Color borderColor = const Color(0xFFC8E6C9);
    IconData icon = Icons.info_outline;

    if (type == 'As Needed') {
      message = 'You can take leave whenever required.';
      bgColor = const Color(0xFFE8F5E9); // Light green
      textColor = const Color(0xFF2E7D32);
      borderColor = const Color(0xFFC8E6C9);
      icon = Icons.check_circle_outline;
    } else if (type == 'Manual Allocation' || type == 'Once a Month') {
      final daysStr = emp.allowedLeaves == emp.allowedLeaves.truncateToDouble()
          ? emp.allowedLeaves.toInt().toString()
          : emp.allowedLeaves.toStringAsFixed(1);
      final freqStr = emp.leaveAllocationFrequency.isNotEmpty ? emp.leaveAllocationFrequency.toLowerCase() : 'month';
      message = 'You are allocated $daysStr day(s) of leave per $freqStr.';
      bgColor = const Color(0xFFE3F2FD); // Light blue
      textColor = const Color(0xFF1565C0);
      borderColor = const Color(0xFFBBDEFB);
      icon = Icons.info_outline;
    } else if (type == 'No Leave') {
      message = 'You are not eligible to take leave.';
      bgColor = const Color(0xFFFFEBEE); // Light red
      textColor = const Color(0xFFC62828);
      borderColor = const Color(0xFFFFCDD2);
      icon = Icons.warning_amber_outlined;
    } else {
      message = 'Leave Policy: $type. You can take leave whenever required.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(int currentEmpId) {
    final leaveAsync = ref.watch(leaveRequestsProvider(currentEmpId));

    return leaveAsync.when(
      loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => Card(child: Text('Error: $e')),
      data: (requests) {
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
              // Header with Month Navigation
              Row(
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
              ..._buildCalendarRows(requests),

              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFF2E7D32), 'Approved'),
                  const SizedBox(width: 16),
                  _buildLegendItem(const Color(0xFFE53935), 'Loss of Pay (LOP)'),
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

          final leaveColor = _getCellColor(dateNorm, requests);
          final tooltipMsg = _getCellTooltip(dateNorm, requests);

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

  Widget _buildLeaveListCard(int currentEmpId) {
    final requestsAsync = ref.watch(leaveRequestsProvider(currentEmpId));

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
                'Your Leave Requests',
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
            data: (list) {
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
                  return _buildLeaveRequestTile(req);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestTile(LeaveRequest req) {
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
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 20)),
            onPressed: () => _showAuditHistoryDialog(req.id),
            icon: const Icon(Icons.history, size: 12),
            label: const Text('View Audit History', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryLopCalculationCard(int employeeId) {
    final int currentYear = _focusedMonth.year;
    final int currentMonth = _focusedMonth.month;

    final calcAsync = ref.watch(
      salaryCalculationProvider(
        SalaryCalcParam(
          employeeId: employeeId,
          year: currentYear,
          month: currentMonth,
          workingDays: 26,
        ),
      ),
    );

    return Container(
      width: double.infinity,
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
              Icon(Icons.calculate_outlined, color: AppColors.active, size: 22),
              SizedBox(width: 8),
              Text(
                'Salary & Loss of Pay Calculation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          calcAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error fetching calculations: $e'),
            data: (calc) {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildCalcTile('Gross Monthly Salary', '₹${NumberFormat('#,##,###').format(calc.grossMonthlySalary)}'),
                      _buildCalcTile('Total Working Days', '${calc.totalWorkingDays} days'),
                      _buildCalcTile('Per Day Salary', '₹${calc.perDaySalary.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildCalcTile('Approved Leave Days', '${calc.totalApprovedLeaveDays} days'),
                      _buildCalcTile('Total LOP Days', '${calc.totalLopDays} days', valueColor: const Color(0xFFE53935)),
                      _buildCalcTile('LOP Deduction Amount', '₹${calc.lopDeductionAmount.toStringAsFixed(2)}', valueColor: const Color(0xFFE53935)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Final Payable Salary',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###.00').format(calc.finalPayableSalary)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalcTile(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE9ECEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewLeaveDialog(Employee currentEmp) {
    final fromDateController = TextEditingController();
    final toDateController = TextEditingController();
    final reasonController = TextEditingController();
    String leaveType = currentEmp.leaveType.isNotEmpty ? currentEmp.leaveType : 'As Needed';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.event_available, color: AppColors.active, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'New Leave Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'From Date',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: fromDateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  hintText: 'Select date',
                                  hintStyle: TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2040),
                                  );
                                  if (picked != null) {
                                    final day = picked.day.toString().padLeft(2, '0');
                                    final month = picked.month.toString().padLeft(2, '0');
                                    fromDateController.text = '$day-$month-${picked.year}';
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'To Date',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: toDateController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  hintText: 'Select date',
                                  hintStyle: TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                                ),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2040),
                                  );
                                  if (picked != null) {
                                    final day = picked.day.toString().padLeft(2, '0');
                                    final month = picked.month.toString().padLeft(2, '0');
                                    toDateController.text = '$day-$month-${picked.year}';
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reason',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter reason for leave',
                        hintStyle: TextStyle(fontSize: 13),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    if (fromDateController.text.trim().isEmpty || toDateController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please select both From and To dates'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final fromDate = _parseDate(fromDateController.text.trim());
                    final toDate = _parseDate(toDateController.text.trim());
                    if (fromDate == null || toDate == null || fromDate.isAfter(toDate)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid date range selected.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final days = toDate.difference(fromDate).inDays + 1.0;

                    final request = LeaveRequest(
                      id: 0,
                      employeeId: currentEmp.id,
                      employeeName: currentEmp.fullName,
                      employeeCustomId: currentEmp.employeeId,
                      leaveType: leaveType,
                      fromDate: fromDateController.text.trim(),
                      toDate: toDateController.text.trim(),
                      numDays: days,
                      reason: reasonController.text.trim(),
                      status: 'Pending',
                      createdAt: DateTime.now().toIso8601String(),
                    );

                    try {
                      await ref.read(leaveRepositoryProvider).submitLeaveRequest(request);
                      ref.invalidate(leaveRequestsProvider(currentEmp.id));
                      ref.invalidate(leaveBalancesProvider(currentEmp.id));
                      ref.invalidate(salaryCalculationProvider);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Leave request submitted successfully!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Failed to submit: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Request', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
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
