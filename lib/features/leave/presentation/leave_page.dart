import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // Demo employee ID — swap with real auth context later
  static const int _demoEmployeeId = 1;

  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final leaveAsync = ref.watch(leaveRequestsProvider(_demoEmployeeId));

    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (employees) {
        final employee = employees.firstWhere(
          (e) => e.id == _demoEmployeeId,
          orElse: () => const Employee(
            id: 0,
            employeeId: '',
            firstName: 'Unknown',
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
          ),
        );

        final leaveType = employee.leaveType.isEmpty ? 'As Needed' : employee.leaveType;
        final leaveRequests = leaveAsync.valueOrNull ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFEFF3F6),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 22, color: AppColors.active),
                    const SizedBox(width: 8),
                    const Text(
                      'Leave Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (leaveType != 'No Leave')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.active,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showNewLeaveDialog(leaveType),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          '+ New Leave',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Dynamic Status Message
                _buildStatusMessage(leaveType),
                const SizedBox(height: 20),
                // Calendar + Leave List
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCalendarCard(leaveRequests),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 2,
                              child: _buildLeaveListCard(leaveRequests),
                            ),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildCalendarCard(leaveRequests),
                            const SizedBox(height: 20),
                            _buildLeaveListCard(leaveRequests),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusMessage(String leaveType) {
    IconData icon;
    Color bgColor;
    Color iconColor;
    String message;

    switch (leaveType) {
      case 'Once a Month':
        icon = Icons.info_outline;
        bgColor = const Color(0xFFFFF3E0);
        iconColor = const Color(0xFFE65100);
        message = 'You are allowed to take one day of leave this month.';
        break;
      case 'No Leave':
        icon = Icons.block;
        bgColor = const Color(0xFFFFEBEE);
        iconColor = const Color(0xFFC62828);
        message = 'You are not eligible to take leave.';
        break;
      case 'As Needed':
      default:
        icon = Icons.check_circle_outline;
        bgColor = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF2E7D32);
        message = 'You can take leave whenever required.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(List<LeaveRequest> leaveRequests) {
    final leaveDates = <DateTime>{};
    for (final req in leaveRequests) {
      final parsed = _parseDate(req.date);
      if (parsed != null) leaveDates.add(DateTime(parsed.year, parsed.month, parsed.day));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          // Day-of-week headers
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
          // Calendar Grid
          ..._buildCalendarRows(leaveDates),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows(Set<DateTime> leaveDates) {
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
          final isLeave = leaveDates.contains(dateNorm);

          cells.add(
            Expanded(
              child: Container(
                height: 40,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isLeave
                      ? const Color(0xFFE53935)
                      : isToday
                          ? AppColors.active
                          : null,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isLeave
                      ? null
                      : null,
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday || isLeave ? FontWeight.bold : FontWeight.w500,
                      color: isLeave || isToday
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        day++;
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  Widget _buildLeaveListCard(List<LeaveRequest> leaveRequests) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: AppColors.active),
              SizedBox(width: 8),
              Text(
                'Leave Requests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (leaveRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: const Column(
                children: [
                  Icon(Icons.event_busy, size: 40, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'No leave requests yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...leaveRequests.map((req) => _buildLeaveRequestTile(req)),
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
      case 'Rejected':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFE65100);
        statusIcon = Icons.hourglass_bottom;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: AppColors.active),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.date,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (req.reason.isNotEmpty)
                  Text(
                    req.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  req.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewLeaveDialog(String leaveType) {
    final dateController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
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
                const Text(
                  'Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Select date',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) {
                          final day = picked.day.toString().padLeft(2, '0');
                          final month = picked.month.toString().padLeft(2, '0');
                          dateController.text = '$day-$month-${picked.year}';
                        }
                      },
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      final day = picked.day.toString().padLeft(2, '0');
                      final month = picked.month.toString().padLeft(2, '0');
                      dateController.text = '$day-$month-${picked.year}';
                    }
                  },
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
                if (dateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a date'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final request = LeaveRequest(
                  id: 0,
                  employeeId: _demoEmployeeId,
                  date: dateController.text.trim(),
                  reason: reasonController.text.trim(),
                  status: 'Pending',
                  createdAt: DateTime.now().toIso8601String(),
                );

                try {
                  await ref.read(leaveRepositoryProvider).submitLeaveRequest(request);
                  ref.invalidate(leaveRequestsProvider(_demoEmployeeId));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
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
  }

  DateTime? _parseDate(String dateStr) {
    try {
      // Expected format: dd-MM-yyyy
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

  String _monthYearString(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
