import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/task_item.dart';
import '../providers/task_providers.dart';
import '../../employee/providers/employee_providers.dart';
import '../../time_clocking/providers/clocking_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../on_duty/providers/on_duty_providers.dart';

class MyTasksPage extends ConsumerStatefulWidget {
  const MyTasksPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  ConsumerState<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends ConsumerState<MyTasksPage> {
  Timer? _tickerTimer;
  String _selectedEmployeeId = 'EMP-001';
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Start periodic timer to refresh live duration for IN_PROGRESS tasks
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    final clockingRepo = ref.read(clockingRepositoryProvider);
    final rawEmpId = task.assignedTo.isNotEmpty ? task.assignedTo : _selectedEmployeeId;
    final empId = rawEmpId == 'EMP-0001' ? 'EMP-001' : rawEmpId;
    final now = DateTime.now();

    // 0. Check attendance status for assigned employee
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(now);
    final digits = empId.replaceAll(RegExp(r'[^0-9]'), '');
    final empIdInt = int.tryParse(digits) ?? 1;
    final attendanceRecord = await attendanceRepo.getAttendanceRecordForDate(empIdInt, today);

    if (attendanceRecord == null || attendanceRecord.effectiveCheckInTime.trim().isEmpty) {
      if (mounted) {
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
              'You need to check in before starting work on a task.',
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
      if (mounted) {
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
              'Your attendance status is marked Absent for today because check-in exceeded the late limit cutoff. You cannot start work on tasks.',
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
      if (mounted) {
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
              'You have already checked out for today. You cannot start work on a task after checking out.',
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

    // Check if On-Duty is IN_PROGRESS
    final onDutyRepo = ref.read(onDutyRepositoryProvider);
    final activeOD = await onDutyRepo.getActiveAssignmentForEmployee(empIdInt);
    if (activeOD != null && (activeOD.status == 'IN_PROGRESS' || activeOD.status == 'ACTIVE')) {
      if (mounted) {
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
              'On-Duty task "${activeOD.odType}" (${activeOD.destination}) is currently in progress.\n\nPlease complete On-Duty before starting a task.',
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

    // 1. Check if a Clocking activity is currently running
    final activeClocking = await clockingRepo.getActiveEntry(empId) ??
        await clockingRepo.getActiveEntry('EMP-001') ??
        await clockingRepo.getActiveEntry('EMP-0001');

    if (activeClocking != null) {
      if (mounted) {
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
                    'Activity Currently Running',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            content: Text(
              'Clocking activity "${activeClocking.entryType}" is currently running.\n\nPlease stop your active clocking activity before starting a task.',
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

    // 2. Auto-complete any other task currently IN_PROGRESS for this employee
    final allTasks = await repo.getTasks(assignedTo: empId);
    for (final t in allTasks) {
      if (t.status == 'IN_PROGRESS' && t.id != task.id) {
        await repo.updateTask(t.copyWith(status: 'COMPLETED', endTime: now));
      }
    }

    // 3. Start the target task
    final updatedTask = task.copyWith(
      status: 'IN_PROGRESS',
      startTime: now,
    );
    await repo.updateTask(updatedTask);
    _refreshAll(empId);
  }

  Future<void> _stopTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    final empId = task.assignedTo.isNotEmpty ? task.assignedTo : _selectedEmployeeId;
    final updatedTask = task.copyWith(
      status: 'COMPLETED',
      endTime: DateTime.now(),
    );
    await repo.updateTask(updatedTask);
    _refreshAll(empId);
  }

  void _refreshAll(String empId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.invalidate(tasksProvider);
    ref.invalidate(activeTaskProvider(empId));
    ref.invalidate(activeTaskProvider('EMP-001'));
    ref.invalidate(activeTaskProvider('EMP-0001'));
    ref.invalidate(taskProjectHoursProvider);
    ref.invalidate(activeClockEntryProvider(empId));
    ref.invalidate(clockEntriesProvider((employeeId: empId, date: today)));
    ref.invalidate(totalWorkHoursProvider((employeeId: empId, date: today)));
    ref.invalidate(totalBreakHoursProvider((employeeId: empId, date: today)));
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatTotalHoursMinutes(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.valueOrNull ?? [];

    final tasksAsync = ref.watch(
      tasksProvider((
        assignedTo: _selectedEmployeeId == 'All' ? null : _selectedEmployeeId,
        projectOrOfficeCode: null,
        status: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
      )),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee Filter Selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedEmployeeId,
                isExpanded: true,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                items: [
                  const DropdownMenuItem(
                    value: 'EMP-001',
                    child: Text('EMP-001 (Current Employee)'),
                  ),
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All Employees / All Tasks'),
                  ),
                  ...employees.map(
                    (emp) => DropdownMenuItem(
                      value: emp.employeeId,
                      child: Text('${emp.employeeId} - ${emp.fullName}'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedEmployeeId = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChip('All', 'All Tasks', primaryColor),
                const SizedBox(width: 8),
                _buildStatusChip('TODO', 'To Do', primaryColor),
                const SizedBox(width: 8),
                _buildStatusChip('IN_PROGRESS', 'In Progress', primaryColor),
                const SizedBox(width: 8),
                _buildStatusChip('COMPLETED', 'Completed', primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section Label
          Row(
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Task List
          tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No assigned tasks found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tasks assigned to you will appear here.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: tasks.map((task) => _buildTaskCard(context, task, primaryColor, secondaryColor)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error loading tasks: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskItem task,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final status = task.status;
    final isTodo = status == 'TODO';
    final isInProgress = status == 'IN_PROGRESS';
    final isCompleted = status == 'COMPLETED';

    final startTimeStr = DateFormat('h:mm a').format(task.startTime);
    final endTimeStr = task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isInProgress ? primaryColor : Colors.grey.shade200,
          width: isInProgress ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isInProgress ? primaryColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Code Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.projectOrOfficeCode,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                    if (task.assignedBy.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Assigned by: ${task.assignedBy}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status Badge
              _buildStatusBadge(status, primaryColor),
            ],
          ),
          const SizedBox(height: 16),

          // State 1: TODO -> Start Task button
          if (isTodo) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _startTask(task),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'Start Task',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // State 2: IN_PROGRESS -> Started time, Live duration, Stop Task button
          if (isInProgress) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_filled, color: primaryColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Started: $startTimeStr',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: primaryColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${_formatDuration(task.duration)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _stopTask(task),
                icon: const Icon(Icons.stop_rounded, size: 22),
                label: const Text(
                  'Stop Task',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // State 3: COMPLETED -> Time range, Total duration, Completed badge
          if (isCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    '$startTimeStr → $endTimeStr',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Total: ${_formatTotalHoursMinutes(task.duration)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color primaryColor) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'IN_PROGRESS':
        bg = primaryColor.withValues(alpha: 0.15);
        text = primaryColor;
        label = 'In Progress';
        break;
      case 'COMPLETED':
        bg = Colors.green.shade50;
        text = Colors.green.shade700;
        label = 'Completed';
        break;
      case 'TODO':
      default:
        bg = Colors.amber.shade50;
        text = Colors.amber.shade800;
        label = 'To Do';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String value, String label, Color primaryColor) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? primaryColor : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatusFilter = value);
        }
      },
    );
  }
}
