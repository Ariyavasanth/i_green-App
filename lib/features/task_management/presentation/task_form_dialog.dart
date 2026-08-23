import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/task_item.dart';
import '../providers/task_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../on_duty/providers/on_duty_providers.dart';

class TaskFormDialog extends ConsumerStatefulWidget {
  const TaskFormDialog({
    super.key,
    this.existingTask,
    this.onTaskSaved,
  });

  final TaskItem? existingTask;
  final VoidCallback? onTaskSaved;

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _codeController;
  String? _selectedAssignedTo;
  String _status = 'TODO';
  DateTime _startTime = DateTime.now();
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _codeController = TextEditingController(text: task?.projectOrOfficeCode ?? 'PRJ-101');
    _selectedAssignedTo = task?.assignedTo;
    _status = task?.status ?? 'TODO';
    if (task != null) {
      _startTime = task.startTime;
      _endTime = task.endTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    if (_status == 'IN_PROGRESS') {
      final empIdStr = _selectedAssignedTo ?? 'EMP-001';
      final digits = empIdStr.replaceAll(RegExp(r'[^0-9]'), '');
      final empIdInt = int.tryParse(digits) ?? 1;

      final onDutyRepo = ref.read(onDutyRepositoryProvider);
      final activeOD = await onDutyRepo.getActiveAssignmentForEmployee(empIdInt);
      if (activeOD != null && (activeOD.status == 'IN_PROGRESS' || activeOD.status == 'ACTIVE')) {
        _status = 'TODO';
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Employee Currently On-Duty',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
              content: Text(
                'The assigned employee is currently doing On-Duty (${activeOD.odType} - ${activeOD.destination}).\n\nThis task will be saved as TODO so the employee can start it after completing On-Duty.',
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
      }

      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
                'The assigned employee must check in before setting task status to In Progress.',
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
                'The assigned employee is marked Absent for today. Task status cannot be set to In Progress.',
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
                'The assigned employee has already checked out for today. Task status cannot be set to In Progress.',
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
    }

    final repo = ref.read(taskRepositoryProvider);
    final taskId = widget.existingTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final task = TaskItem(
      id: taskId,
      title: _titleController.text.trim(),
      projectOrOfficeCode: _codeController.text.trim().toUpperCase(),
      assignedBy: 'Admin',
      assignedTo: _selectedAssignedTo ?? 'EMP-001',
      startTime: _startTime,
      endTime: _endTime,
      status: _status,
    );

    if (widget.existingTask == null) {
      await repo.createTask(task);
    } else {
      await repo.updateTask(task);
    }

    ref.invalidate(tasksProvider);
    ref.invalidate(taskProjectHoursProvider);

    if (widget.onTaskSaved != null) {
      widget.onTaskSaved!();
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingTask == null ? 'Task created successfully' : 'Task updated successfully'),
          backgroundColor: const Color(0xFF9CC70A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.valueOrNull ?? [];
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final empIdStr = _selectedAssignedTo ?? 'EMP-001';
    final digits = empIdStr.replaceAll(RegExp(r'[^0-9]'), '');
    final empIdInt = int.tryParse(digits) ?? 1;
    final activeODAsync = ref.watch(activeOnDutyAssignmentProvider(empIdInt));
    final activeOD = activeODAsync.valueOrNull;
    final isOnDutyRunning = activeOD != null && (activeOD.status == 'IN_PROGRESS' || activeOD.status == 'ACTIVE');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        width: screenWidth * 0.95,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_turned_in_outlined, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.existingTask == null ? 'Create Task Assignment' : 'Edit Task Assignment',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title *',
                    hintText: 'e.g. Implement Riverpod state management',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                if (isMobile) ...[
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Project / Office Code *',
                      hintText: 'e.g. PRJ-102, OFFICE-GEN',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAssignedTo,
                    decoration: const InputDecoration(
                      labelText: 'Assign To',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'EMP-001', child: Text('EMP-001 (Self)')),
                      ...employees.map(
                        (emp) => DropdownMenuItem(
                          value: emp.employeeId,
                          child: Text('${emp.employeeId} - ${emp.fullName}'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedAssignedTo = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODO', child: Text('TODO')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN_PROGRESS')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                    ],
                    onChanged: (val) => setState(() => _status = val ?? 'TODO'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(DateFormat('dd MMM yyyy').format(_startTime)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Project / Office Code *',
                            hintText: 'e.g. PRJ-102, OFFICE-GEN',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAssignedTo,
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'EMP-001', child: Text('EMP-001 (Self)')),
                            ...employees.map(
                              (emp) => DropdownMenuItem(
                                value: emp.employeeId,
                                child: Text('${emp.employeeId} - ${emp.fullName}'),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _selectedAssignedTo = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'TODO', child: Text('TODO')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN_PROGRESS')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('COMPLETED')),
                          ],
                          onChanged: (val) => setState(() => _status = val ?? 'TODO'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startTime,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _startTime = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(DateFormat('dd MMM yyyy').format(_startTime)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isOnDutyRunning) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ℹ️ Notice: Selected employee is currently on On-Duty (${activeOD.odType} - ${activeOD.destination}). This task will be added as TODO so they can start it after completing OD.',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    if (widget.existingTask != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () async {
                          final repo = ref.read(taskRepositoryProvider);
                          await repo.deleteTask(widget.existingTask!.id);
                          ref.invalidate(tasksProvider);
                          ref.invalidate(taskProjectHoursProvider);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Task deleted successfully'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: _saveTask,
                          child: Text(widget.existingTask == null ? 'Create Task' : 'Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
