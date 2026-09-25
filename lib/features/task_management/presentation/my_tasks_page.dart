import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/task_item.dart';
import '../providers/task_providers.dart';
import 'task_form_dialog.dart';
import 'task_completion_dialog.dart';
import '../../time_clocking/providers/clocking_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../on_duty/providers/on_duty_providers.dart';
import '../../employee/providers/employee_providers.dart';

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
  final String _selectedEmployeeId = 'All';
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Start periodic timer to refresh live duration & SLA status for tasks
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

  void _openSelfAssignDialog() {
    final currentEmp = ref.read(currentEmployeeProvider);
    showDialog(
      context: context,
      builder: (ctx) => TaskFormDialog(
        isSelfAssign: true,
        initialAssignedTo: currentEmp?.employeeId,
      ),
    );
  }

  Future<void> _startTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    final clockingRepo = ref.read(clockingRepositoryProvider);
    final currentEmp = ref.read(currentEmployeeProvider);
    final empId = task.assignedTo.isNotEmpty ? task.assignedTo : (currentEmp?.employeeId ?? '');
    if (empId.isEmpty) return;
    final now = DateTime.now();

    // 0. Check attendance status for assigned employee
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(now);
    final digits = empId.replaceAll(RegExp(r'[^0-9]'), '');
    final empIdInt = int.tryParse(digits) ?? (currentEmp?.id ?? 0);
    if (empIdInt == 0) return;
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
    final activeClocking = await clockingRepo.getActiveEntry(empId);

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

    // 2. Pause any other task currently IN_PROGRESS for this employee
    final allTasks = await repo.getTasks(assignedTo: empId);
    for (final t in allTasks) {
      if (t.status == 'IN_PROGRESS' && t.id != task.id && !t.isPaused) {
        await repo.updateTask(t.copyWith(
          isPaused: true,
          accumulatedSeconds: t.duration.inSeconds,
        ));
      }
    }

    // 3. Start the target task
    final updatedTask = task.copyWith(
      status: 'IN_PROGRESS',
      isPaused: false,
      startTime: task.startTime,
      lastResumedAt: now,
    );
    await repo.updateTask(updatedTask);
    _refreshAll(empId);
  }

  Future<void> _pauseTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    final currentEmp = ref.read(currentEmployeeProvider);
    final empId = task.assignedTo.isNotEmpty ? task.assignedTo : (currentEmp?.employeeId ?? '');
    final updatedTask = task.copyWith(
      isPaused: true,
      accumulatedSeconds: task.duration.inSeconds,
      status: 'IN_PROGRESS',
    );
    await repo.updateTask(updatedTask);
    _refreshAll(empId);
  }

  Future<void> _resumeTask(TaskItem task) async {
    final repo = ref.read(taskRepositoryProvider);
    final currentEmp = ref.read(currentEmployeeProvider);
    final empId = task.assignedTo.isNotEmpty ? task.assignedTo : (currentEmp?.employeeId ?? '');
    final now = DateTime.now();

    // Auto-pause any other running task
    final allTasks = await repo.getTasks(assignedTo: empId);
    for (final t in allTasks) {
      if (t.status == 'IN_PROGRESS' && t.id != task.id && !t.isPaused) {
        await repo.updateTask(t.copyWith(
          isPaused: true,
          accumulatedSeconds: t.duration.inSeconds,
        ));
      }
    }

    final updatedTask = task.copyWith(
      isPaused: false,
      lastResumedAt: now,
      status: 'IN_PROGRESS',
    );
    await repo.updateTask(updatedTask);
    _refreshAll(empId);
  }

  void _openCompletionDialog(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => TaskCompletionDialog(
        task: task,
        onCompleted: () => _refreshAll(task.assignedTo),
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String base64Image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Completion Photo Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 450),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImageFromBase64(base64Image),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFromBase64(String base64String) {
    try {
      final clean = base64String.contains(',') ? base64String.split(',').last : base64String;
      return Image.memory(
        base64Decode(clean),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      );
    }
  }

  void _refreshAll(String empId) {
    if (empId.isEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.invalidate(tasksProvider);
    ref.invalidate(activeTaskProvider(empId));
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'VERY_HIGH':
        return Colors.red.shade700;
      case 'HIGH':
        return Colors.orange.shade800;
      case 'MEDIUM':
        return Colors.blue.shade700;
      case 'LOW':
      default:
        return const Color(0xFF414A51);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final currentEmp = ref.watch(currentEmployeeProvider);
    final canManageAllTasks = currentEmp != null &&
        (currentEmp.isSuperAdmin || currentEmp.hasPermission('Tasks and Clocking Management'));
    final effectiveAssignedTo = canManageAllTasks
        ? (_selectedEmployeeId == 'All' ? null : _selectedEmployeeId)
        : (currentEmp?.employeeId ?? 'UNAUTHENTICATED');

    final tasksAsync = ref.watch(
      tasksProvider((
        assignedTo: effectiveAssignedTo,
        projectOrOfficeCode: null,
        status: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: _openSelfAssignDialog,
        icon: const Icon(Icons.add_task_rounded, size: 20),
        label: const Text('Self-Assign Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          ref.invalidate(tasksProvider);
          ref.invalidate(currentEmployeeProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text(
                'My Assigned Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

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
                          const SizedBox(height: 6),
                          const Text(
                            'You can self-assign a task to start tracking work immediately.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: _openSelfAssignDialog,
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                            label: const Text('Self-Assign a Task', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ),
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
    final isBreached = task.isBreached;
    final isPaused = task.isPaused;

    final startTimeStr = DateFormat('h:mm a').format(task.startTime);
    final endTimeStr = task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : '';
    final deadlineStr = DateFormat('dd MMM, h:mm a').format(task.deadline);
    final priorityColor = _getPriorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBreached ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBreached
              ? (isInProgress ? Colors.red.shade400 : const Color(0xFFCBD5E1))
              : (isInProgress ? (isPaused ? Colors.amber.shade400 : primaryColor) : Colors.grey.shade200),
          width: (isInProgress || isBreached) ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isInProgress
                ? (isBreached ? Colors.red.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.12))
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code & Priority Badge, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.projectOrOfficeCode,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 12, color: priorityColor),
                        const SizedBox(width: 4),
                        Text(
                          task.priority.replaceAll('_', ' '),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isInProgress && isPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle_filled, size: 12, color: Colors.amber.shade800),
                          const SizedBox(width: 3),
                          Text(
                            'PAUSED',
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  if (isBreached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted
                                ? 'BREACHED BY ${task.formattedBreachDuration.toUpperCase()}'
                                : 'SLA BREACHED',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              _buildStatusBadge(status, primaryColor),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Assignee Details
          Text(
            task.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isBreached ? const Color(0xFF334155) : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          if (task.assignedBy.isNotEmpty)
            Text(
              'Assigned by: ${task.assignedBy}',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
          const SizedBox(height: 10),

          // SLA & Deadline Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isBreached
                  ? Colors.red.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBreached ? Colors.red.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBreached ? Icons.error_outline : Icons.schedule,
                      size: 14,
                      color: isBreached ? Colors.red.shade700 : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Deadline: $deadlineStr',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isBreached ? Colors.red.shade800 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                if (!isCompleted && !isBreached)
                  Text(
                    '${task.formattedRemainingSla} left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  )
                else if (isCompleted && !isBreached)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'On Time',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action State 1: TODO -> Start Task button
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

          // Action State 2: IN_PROGRESS -> Live duration/pause info + Pause/Resume & Complete buttons
          if (isInProgress) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isBreached
                    ? Colors.red.withValues(alpha: 0.08)
                    : (isPaused ? Colors.amber.withValues(alpha: 0.08) : primaryColor.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isBreached
                      ? Colors.red.withValues(alpha: 0.25)
                      : (isPaused ? Colors.amber.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.2)),
                ),
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
                      Icon(
                        isPaused ? Icons.pause_circle_outline : Icons.access_time_filled,
                        color: isBreached ? Colors.red.shade700 : (isPaused ? Colors.amber.shade800 : primaryColor),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaused ? 'Paused (Started: $startTimeStr)' : 'Running (Started: $startTimeStr)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: isBreached ? Colors.red.shade700 : (isPaused ? Colors.amber.shade800 : primaryColor),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Time Spent: ${_formatDuration(task.duration)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isBreached ? Colors.red.shade700 : const Color(0xFF1E293B),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Two Action Buttons: Pause/Resume Task & Completed
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isPaused ? const Color(0xFF1D4ED8) : const Color(0xFFD97706),
                        side: BorderSide(
                          color: isPaused ? const Color(0xFF93C5FD) : const Color(0xFFFCD34D),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => isPaused ? _resumeTask(task) : _pauseTask(task),
                      icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                      label: Text(
                        isPaused ? 'Resume Task' : 'Pause Task',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => _openCompletionDialog(task),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'Completed',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Action State 3: COMPLETED -> Time range, Total duration, Completion Description & Photo Proof
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
                    'Time Spent: ${_formatTotalHoursMinutes(task.duration)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            if (task.completionDescription != null && task.completionDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text('Completion Note:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.completionDescription!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            ],
            if (task.completionPhotoUrl != null && task.completionPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showImagePreviewDialog(context, task.completionPhotoUrl!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: _buildImageFromBase64(task.completionPhotoUrl!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'View Photo Proof',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
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
