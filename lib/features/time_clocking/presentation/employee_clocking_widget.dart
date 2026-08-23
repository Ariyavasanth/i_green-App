import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/clock_entry.dart';
import '../providers/clocking_providers.dart';
import '../../task_management/domain/task_item.dart';
import '../../task_management/providers/task_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../on_duty/domain/on_duty_assignment.dart';
import '../../on_duty/providers/on_duty_providers.dart';
import '../../on_duty/presentation/employee_on_duty_card.dart';

class CombinedActivityItem {
  final String title;
  final String subtitle;
  final String type; // 'TASK' or 'CLOCKING'
  final DateTime startTime;
  final DateTime? endTime;
  final String durationText;
  final bool isRunning;
  final IconData icon;

  CombinedActivityItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.startTime,
    this.endTime,
    required this.durationText,
    required this.isRunning,
    required this.icon,
  });
}

class EmployeeClockingWidget extends ConsumerStatefulWidget {
  const EmployeeClockingWidget({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  ConsumerState<EmployeeClockingWidget> createState() => _EmployeeClockingWidgetState();
}

class _EmployeeClockingWidgetState extends ConsumerState<EmployeeClockingWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Periodic timer to refresh active activity duration UI every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showStartActivityDialog(BuildContext context) async {
    final taskRepo = ref.read(taskRepositoryProvider);
    final empId = widget.employeeId == 'EMP-0001' ? 'EMP-001' : widget.employeeId;

    // Check attendance status
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final digits = empId.replaceAll(RegExp(r'[^0-9]'), '');
    final empIdInt = int.tryParse(digits) ?? 1;
    final attendanceRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, today);

    if (attendanceRecord == null || attendanceRecord.effectiveCheckInTime.trim().isEmpty) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check In Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'You need to check in before starting any clocking activity.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (attendanceRecord.status == 'Absent') {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attendance Marked Absent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your attendance status is marked Absent for today because check-in exceeded the late limit cutoff. You cannot start clocking activities.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (attendanceRecord.checkOutTime.trim().isNotEmpty || attendanceRecord.status == 'Checked Out') {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Already Checked Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: const Text(
              'You have already checked out for today. You cannot start a clocking activity after checking out.',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Mutual Exclusion Check: If On-Duty is IN_PROGRESS, prevent starting clocking activity
    final onDutyRepo = ref.read(onDutyRepositoryProvider);
    final activeOD = await onDutyRepo.getActiveAssignmentForEmployee(empIdInt);
    if (activeOD != null && (activeOD.status == 'IN_PROGRESS' || activeOD.status == 'ACTIVE')) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On-Duty Currently Running',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: Text(
              'On-Duty task "${activeOD.odType}" (${activeOD.destination}) is currently in progress.\n\nPlease complete On-Duty before starting a new activity.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check if any Task is currently IN_PROGRESS
    final tasks1 = await taskRepo.getTasks(assignedTo: empId, status: 'IN_PROGRESS');
    final tasks2 = await taskRepo.getTasks(assignedTo: 'EMP-001', status: 'IN_PROGRESS');
    final tasks3 = await taskRepo.getTasks(assignedTo: 'EMP-0001', status: 'IN_PROGRESS');
    final runningTask = [...tasks1, ...tasks2, ...tasks3].firstOrNull;

    if (runningTask != null) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task Currently Running',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: Text(
              'Task "${runningTask.title}" (${runningTask.projectOrOfficeCode}) is currently running.\n\nPlease stop the active task before starting a clocking activity.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    String selectedActivity = 'General Work';
    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.play_circle_fill, color: Color(0xFF9CC70A)),
                  SizedBox(width: 8),
                  Text(
                    'Select Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActivityOption(
                      title: 'General Work',
                      subtitle: 'Regular office tasks without specific project',
                      icon: Icons.work_outline,
                      value: 'General Work',
                      groupValue: selectedActivity,
                      onChanged: (val) => setDialogState(() => selectedActivity = val!),
                    ),
                    _buildActivityOption(
                      title: 'Meeting',
                      subtitle: 'Internal team or client discussion',
                      icon: Icons.groups_outlined,
                      value: 'Meeting',
                      groupValue: selectedActivity,
                      onChanged: (val) => setDialogState(() => selectedActivity = val!),
                    ),
                    _buildActivityOption(
                      title: 'Tea / Coffee Break',
                      subtitle: 'Short refreshment break',
                      icon: Icons.coffee_outlined,
                      value: 'Tea / Coffee Break',
                      groupValue: selectedActivity,
                      onChanged: (val) => setDialogState(() => selectedActivity = val!),
                    ),
                    _buildActivityOption(
                      title: 'Lunch',
                      subtitle: 'Meal break',
                      icon: Icons.restaurant_outlined,
                      value: 'Lunch',
                      groupValue: selectedActivity,
                      onChanged: (val) => setDialogState(() => selectedActivity = val!),
                    ),
                    _buildActivityOption(
                      title: 'Other',
                      subtitle: 'Miscellaneous work activities',
                      icon: Icons.more_horiz_outlined,
                      value: 'Other',
                      groupValue: selectedActivity,
                      onChanged: (val) => setDialogState(() => selectedActivity = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'Notes / Details (Optional)',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Start', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final repo = ref.read(clockingRepositoryProvider);
      final now = DateTime.now();

      final entry = ClockEntry(
        id: now.millisecondsSinceEpoch.toString(),
        employeeId: empId,
        entryType: selectedActivity,
        startTime: now,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );

      await repo.startClockEntry(entry);
      _refreshData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started: $selectedActivity'),
            backgroundColor: const Color(0xFF9CC70A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildActivityOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF9CC70A).withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: const Color(0xFF9CC70A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        title: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF414A51) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

  Future<void> _stopActivity(BuildContext context) async {
    final repo = ref.read(clockingRepositoryProvider);
    await repo.clockOutActiveEntry(widget.employeeId);
    await repo.clockOutActiveEntry('EMP-001');
    await repo.clockOutActiveEntry('EMP-0001');
    _refreshData();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activity stopped'),
          backgroundColor: Color(0xFF414A51),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _refreshData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.invalidate(activeClockEntryProvider(widget.employeeId));
    ref.invalidate(activeClockEntryProvider('EMP-001'));
    ref.invalidate(activeClockEntryProvider('EMP-0001'));
    ref.invalidate(activeTaskProvider(widget.employeeId));
    ref.invalidate(activeTaskProvider('EMP-001'));
    ref.invalidate(activeTaskProvider('EMP-0001'));
    ref.invalidate(clockEntriesProvider((employeeId: widget.employeeId, date: today)));
    ref.invalidate(clockEntriesProvider((employeeId: 'EMP-001', date: today)));
    ref.invalidate(clockEntriesProvider((employeeId: 'EMP-0001', date: today)));
    ref.invalidate(totalWorkHoursProvider((employeeId: widget.employeeId, date: today)));
    ref.invalidate(totalWorkHoursProvider((employeeId: 'EMP-001', date: today)));
    ref.invalidate(totalWorkHoursProvider((employeeId: 'EMP-0001', date: today)));
    ref.invalidate(totalBreakHoursProvider((employeeId: widget.employeeId, date: today)));
    ref.invalidate(totalBreakHoursProvider((employeeId: 'EMP-001', date: today)));
    ref.invalidate(totalBreakHoursProvider((employeeId: 'EMP-0001', date: today)));
    ref.invalidate(tasksProvider);
    ref.invalidate(taskProjectHoursProvider);
  }

  IconData _getActivityIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('meeting')) return Icons.groups;
    if (lower.contains('tea') || lower.contains('coffee')) return Icons.coffee;
    if (lower.contains('lunch')) return Icons.restaurant;
    if (lower.contains('work')) return Icons.work;
    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeEntryAsync = ref.watch(activeClockEntryProvider(widget.employeeId));
    final activeTaskAsync = ref.watch(activeTaskProvider(widget.employeeId));
    final entriesAsync = ref.watch(clockEntriesProvider((employeeId: widget.employeeId, date: today)));

    final empInt = int.tryParse(widget.employeeId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final activeODAsync = ref.watch(activeOnDutyAssignmentProvider(empInt));
    final fallbackODAsync1 = empInt != 1 ? ref.watch(activeOnDutyAssignmentProvider(1)) : null;
    final fallbackODAsync0 = empInt != 0 ? ref.watch(activeOnDutyAssignmentProvider(0)) : null;
    final activeOD = activeODAsync.valueOrNull ?? fallbackODAsync1?.valueOrNull ?? fallbackODAsync0?.valueOrNull;

    final activeEntry = activeEntryAsync.valueOrNull;
    final activeTask = activeTaskAsync.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        const Text(
          'Current Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),

        // Current Activity Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (activeEntry != null || activeTask != null || activeOD != null) ? primaryColor.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              width: (activeEntry != null || activeTask != null || activeOD != null) ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: activeEntry != null
              ? _buildActiveEntryContent(context, activeEntry, primaryColor, secondaryColor)
              : (activeTask != null
                  ? _buildActiveTaskContent(context, activeTask, primaryColor, secondaryColor)
                  : (activeOD != null
                      ? EmployeeOnDutyCard(assignment: activeOD)
                      : _buildNoActivityContent(context, primaryColor))),
        ),

        const SizedBox(height: 24),

        // Today's Activities List Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Activities",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            if (activeEntry == null && activeTask == null)
              InkWell(
                onTap: () => _showStartActivityDialog(context),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF9CC70A)),
                    SizedBox(width: 2),
                    Text(
                      'Add New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9CC70A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        _buildCombinedActivitiesList(
          entriesAsync: entriesAsync,
          tasksAsync: ref.watch(tasksProvider((assignedTo: widget.employeeId == 'EMP-0001' ? 'EMP-001' : widget.employeeId, projectOrOfficeCode: null, status: null))),
          odAsync: ref.watch(allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null))),
          empId: widget.employeeId == 'EMP-0001' ? 'EMP-001' : widget.employeeId,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        ),
      ],
    );
  }

  Widget _buildCombinedActivitiesList({
    required AsyncValue<List<ClockEntry>> entriesAsync,
    required AsyncValue<List<TaskItem>> tasksAsync,
    required AsyncValue<List<OnDutyAssignment>> odAsync,
    required String empId,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    if (entriesAsync.isLoading || tasksAsync.isLoading || odAsync.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF9CC70A),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Loading activities...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final clockEntries = entriesAsync.valueOrNull ?? [];
    final allTasks = tasksAsync.valueOrNull ?? [];
    final allOd = odAsync.valueOrNull ?? [];
    final todayStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final empTasks = allTasks.where((t) {
      final taskEmp = t.assignedTo == 'EMP-0001' ? 'EMP-001' : t.assignedTo;
      return (taskEmp == empId || taskEmp == 'EMP-001' || taskEmp == 'EMP-0001') &&
          (t.status == 'COMPLETED' || t.status == 'IN_PROGRESS');
    }).toList();

    final empInt = int.tryParse(empId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final empOdAssignments = allOd.where((od) {
      final isEmpMatch = (od.employeeId == empInt) || (empInt == 1 && (od.employeeId == 0 || od.employeeId == 1));
      final isCompleted = od.status.toUpperCase() == 'COMPLETED';
      return isEmpMatch && isCompleted;
    }).toList();

    final List<CombinedActivityItem> combinedList = [];

    for (final e in clockEntries) {
      final startStr = DateFormat('hh:mm a').format(e.startTime);
      final endStr = e.endTime != null ? DateFormat('hh:mm a').format(e.endTime!) : 'Running';
      combinedList.add(CombinedActivityItem(
        title: e.entryType,
        subtitle: '$startStr → $endStr',
        type: 'CLOCKING',
        startTime: e.startTime,
        endTime: e.endTime,
        durationText: e.formattedDuration,
        isRunning: e.isActive,
        icon: _getActivityIcon(e.entryType),
      ));
    }

    for (final t in empTasks) {
      final startStr = DateFormat('hh:mm a').format(t.startTime);
      final endStr = t.endTime != null ? DateFormat('hh:mm a').format(t.endTime!) : 'Running';
      combinedList.add(CombinedActivityItem(
        title: t.title,
        subtitle: '${t.projectOrOfficeCode} • $startStr → $endStr',
        type: 'TASK',
        startTime: t.startTime,
        endTime: t.endTime,
        durationText: t.formattedDuration,
        isRunning: t.status == 'IN_PROGRESS',
        icon: Icons.assignment_turned_in,
      ));
    }

    for (final od in empOdAssignments) {
      DateTime startDt;
      try {
        final d = DateFormat('dd-MM-yyyy').parse(od.date);
        final tStr = od.actualStartTime ?? od.plannedStartTime;
        if (tStr.isNotEmpty) {
          final t = DateFormat('hh:mm a').parse(tStr);
          startDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        } else {
          startDt = d;
        }
      } catch (_) {
        startDt = DateTime.now();
      }

      DateTime? endDt;
      if (od.actualEndTime != null && od.actualEndTime!.isNotEmpty) {
        try {
          final d = DateFormat('dd-MM-yyyy').parse(od.date);
          final t = DateFormat('hh:mm a').parse(od.actualEndTime!);
          endDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        } catch (_) {}
      }

      final startDisplay = od.actualStartTime ?? od.plannedStartTime;
      final endDisplay = od.actualEndTime ?? (od.status == 'COMPLETED' ? 'Completed' : 'Running');
      final durMins = od.durationMinutes;
      final durDisplay = durMins > 0 ? '${durMins ~/ 60}h ${durMins % 60}m' : '--';

      combinedList.add(CombinedActivityItem(
        title: 'On-Duty: ${od.odType}',
        subtitle: '${od.destination} • $startDisplay → $endDisplay',
        type: 'ON_DUTY',
        startTime: startDt,
        endTime: endDt,
        durationText: durDisplay,
        isRunning: od.status == 'IN_PROGRESS',
        icon: Icons.business_center_rounded,
      ));
    }

    combinedList.sort((a, b) => b.startTime.compareTo(a.startTime));

    if (combinedList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No activities recorded yet today.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: combinedList.map((item) {
        final isTask = item.type == 'TASK';
        final isOd = item.type == 'ON_DUTY';
        final isRunning = item.isRunning;

        final badgeBg = isOd
            ? const Color(0xFFFEF3C7)
            : (isTask ? const Color(0xFFF1F5F9) : const Color(0xFFF7FBE6));
        final badgeBorder = isOd
            ? const Color(0xFFFCD34D)
            : (isTask ? const Color(0xFF414A51) : const Color(0xFF9CC70A));
        final badgeText = isOd
            ? const Color(0xFF92400E)
            : (isTask ? const Color(0xFF414A51) : const Color(0xFF5C7700));
        final badgeLabel = isOd ? 'ON-DUTY' : (isTask ? 'TASK' : 'CLOCKING');

        final iconBg = isOd
            ? const Color(0xFFD97706).withValues(alpha: 0.15)
            : (isTask ? const Color(0xFF414A51).withValues(alpha: 0.12) : const Color(0xFF9CC70A).withValues(alpha: 0.15));
        final iconColor = isOd
            ? const Color(0xFFD97706)
            : (isTask ? const Color(0xFF414A51) : const Color(0xFF5C7700));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRunning ? (isOd ? const Color(0xFFD97706) : (isTask ? const Color(0xFF414A51) : primaryColor)) : const Color(0xFFE2E8F0),
              width: isRunning ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: badgeBorder.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isRunning ? const Color(0xFF1E293B) : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTask ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: isTask ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                ),
                child: Text(
                  item.durationText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isTask ? const Color(0xFF334155) : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoActivityContent(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        const Icon(Icons.timer_off_outlined, size: 36, color: Color(0xFF94A3B8)),
        const SizedBox(height: 8),
        const Text(
          'No activity running',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Start an activity to track your general work or break duration.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _showStartActivityDialog(context),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text(
              'Start Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveEntryContent(
    BuildContext context,
    ClockEntry activeEntry,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getActivityIcon(activeEntry.entryType), color: secondaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeEntry.entryType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Started: ${DateFormat('hh:mm a').format(activeEntry.startTime)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeEntry.formattedDuration,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (activeEntry.notes != null && activeEntry.notes!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Note: ${activeEntry.notes}',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => _stopActivity(context),
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text(
              'Stop Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTaskContent(
    BuildContext context,
    TaskItem activeTask,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment_turned_in, color: secondaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTask.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${activeTask.projectOrOfficeCode} • Started: ${DateFormat('hh:mm a').format(activeTask.startTime)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Task Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              final taskRepo = ref.read(taskRepositoryProvider);
              await taskRepo.updateTask(activeTask.copyWith(status: 'COMPLETED', endTime: DateTime.now()));
              _refreshData();
            },
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text(
              'Stop Active Task',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
