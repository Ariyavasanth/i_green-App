import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../time_clocking/presentation/clocking_timeline_view.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/task_item.dart';
import '../providers/task_providers.dart';
import 'task_form_dialog.dart';

class TaskBoardPage extends ConsumerStatefulWidget {
  const TaskBoardPage({
    super.key,
    this.embedded = false,
    this.initialTab = 0,
  });

  final bool embedded;
  final int initialTab;

  @override
  ConsumerState<TaskBoardPage> createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends ConsumerState<TaskBoardPage> {
  late int _activeTab;
  String _selectedDateRange = 'Today';
  DateTimeRange? _customDateRange;
  int? _selectedSpecificDay;
  int? _selectedSpecificMonth;

  String _selectedStatus = 'All';
  String _selectedEmployee = 'All';
  String _selectedPriority = 'All';
  final String _selectedProjectCode = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  void _openCreateTaskDialog([TaskItem? task]) {
    showDialog(
      context: context,
      builder: (ctx) => TaskFormDialog(existingTask: task),
    );
  }

  void _openTaskDetailsDialog(TaskItem task) {
    const primaryColor = Color(0xFF9CC70A);
    final priorityColor = _getPriorityColor(task.priority);
    final isBreached = task.isBreached;
    final isCompleted = task.status == 'COMPLETED';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
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
                            color: const Color(0xFF414A51),
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
                          child: Text(
                            task.priority.replaceAll('_', ' '),
                            style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                                Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  isCompleted
                                      ? 'BREACHED BY ${task.formattedBreachDuration.toUpperCase()}'
                                      : 'SLA BREACHED',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Task Title
                Text(
                  task.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),

                // Assignee & Creator Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.person, color: Color(0xFF64748B), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned To: ${task.assignedTo}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            if (task.assignedBy.isNotEmpty)
                              Text(
                                'Assigned By: ${task.assignedBy}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: task.status == 'COMPLETED'
                              ? primaryColor.withValues(alpha: 0.15)
                              : (task.status == 'IN_PROGRESS' ? Colors.blue.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: task.status == 'COMPLETED'
                                ? primaryColor
                                : (task.status == 'IN_PROGRESS' ? Colors.blue.shade700 : Colors.amber.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // SLA & Timing Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailMetric('Assigned Time', DateFormat('dd MMM yyyy, h:mm a').format(task.assignedAt)),
                          _buildDetailMetric('SLA Duration', '${task.slaDurationHours} hrs (${task.priority.replaceAll('_', ' ')})'),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailMetric('Target Deadline', DateFormat('dd MMM yyyy, h:mm a').format(task.deadline)),
                          _buildDetailMetric(
                            'SLA Status',
                            isBreached
                                ? 'Breached by ${task.formattedBreachDuration}'
                                : (isCompleted ? '✓ Completed On Time' : '${task.formattedRemainingSla} left'),
                            valueColor: isBreached ? Colors.red.shade700 : (isCompleted ? primaryColor : priorityColor),
                          ),
                        ],
                      ),
                      if (isCompleted || task.status == 'IN_PROGRESS') ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailMetric('Started At', DateFormat('h:mm a').format(task.startTime)),
                            _buildDetailMetric(
                              isCompleted ? 'Completed At' : 'Current Time Spent',
                              isCompleted
                                  ? (task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : '-')
                                  : task.formattedDuration,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Completion Note
                if (task.completionDescription != null && task.completionDescription!.trim().isNotEmpty) ...[
                  const Text('Completion Note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      task.completionDescription!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Completion Photo Proof
                if (task.completionPhotoUrl != null && task.completionPhotoUrl!.isNotEmpty) ...[
                  const Text('Completion Photo Proof', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: _buildImageFromBase64(task.completionPhotoUrl!),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Dialog Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteTask(task);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete Task'),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openCreateTaskDialog(task);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
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

  Widget _buildDetailMetric(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF1E293B)),
        ),
      ],
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

  bool _matchesDateFilter(TaskItem task) {
    final now = DateTime.now();
    final taskDate = task.assignedAt;

    switch (_selectedDateRange) {
      case 'Today':
        return taskDate.year == now.year && taskDate.month == now.month && taskDate.day == now.day;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return taskDate.year == yesterday.year && taskDate.month == yesterday.month && taskDate.day == yesterday.day;
      case 'This Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final startOfMonday = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final endOfSunday = startOfMonday.add(const Duration(days: 7));
        return taskDate.isAfter(startOfMonday.subtract(const Duration(seconds: 1))) &&
            taskDate.isBefore(endOfSunday);
      case 'Last Week':
        final lastWeekMonday = now.subtract(Duration(days: now.weekday + 6));
        final startOfMonday = DateTime(lastWeekMonday.year, lastWeekMonday.month, lastWeekMonday.day);
        final endOfSunday = startOfMonday.add(const Duration(days: 7));
        return taskDate.isAfter(startOfMonday.subtract(const Duration(seconds: 1))) &&
            taskDate.isBefore(endOfSunday);
      case 'This Month':
        if (taskDate.year != now.year || taskDate.month != now.month) return false;
        if (_selectedSpecificDay != null) {
          return taskDate.day == _selectedSpecificDay;
        }
        return true;
      case 'Last Month':
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        if (taskDate.year != lastMonthDate.year || taskDate.month != lastMonthDate.month) return false;
        if (_selectedSpecificDay != null) {
          return taskDate.day == _selectedSpecificDay;
        }
        return true;
      case 'This Year':
        if (taskDate.year != now.year) return false;
        if (_selectedSpecificMonth != null) {
          if (taskDate.month != _selectedSpecificMonth) return false;
          if (_selectedSpecificDay != null) {
            return taskDate.day == _selectedSpecificDay;
          }
        }
        return true;
      case 'Custom Range':
        if (_customDateRange == null) return true;
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        return taskDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            taskDate.isBefore(end.add(const Duration(seconds: 1)));
      case 'All Time':
      default:
        return true;
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9CC70A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRange = 'Custom Range';
        _selectedSpecificDay = null;
        _selectedSpecificMonth = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    final isDesktop = MediaQuery.of(context).size.width >= 750;

    final tasksAsync = ref.watch(
      tasksProvider((
        assignedTo: null,
        projectOrOfficeCode: _selectedProjectCode,
        status: null,
      )),
    );

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Desktop Top Navigation Tabs Bar
        if (isDesktop) _buildDesktopTopHeader(primaryColor),

        // Tab 0: Task Tracker
        if (_activeTab == 0) ...[
          const SizedBox(height: 12),
          // 2. Compact 4 KPI Cards
          tasksAsync.when(
            data: (allTasks) {
              final dateScopedTasks = allTasks.where(_matchesDateFilter).toList();
              return _buildCompactKpiGrid(dateScopedTasks, isDesktop);
            },
            loading: () => _buildCompactKpiGrid([], isDesktop),
            error: (_, __) => _buildCompactKpiGrid([], isDesktop),
          ),
          const SizedBox(height: 12),

          // 3. Desktop Single-Row Toolbar / Filters
          _buildDesktopToolbar(primaryColor, isDesktop),

          // 4. Monthly / Yearly Interactive Breakdown
          tasksAsync.when(
            data: (allTasks) => _buildHistoryTimelineBreakdown(allTasks, primaryColor),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // 5. Kanban / Task Board Area
          tasksAsync.when(
            data: (tasks) {
              var filtered = tasks.where((t) {
                if (!_matchesDateFilter(t)) return false;
                if (_selectedEmployee != 'All' && t.assignedTo != _selectedEmployee) return false;
                if (_selectedPriority != 'All' && t.priority != _selectedPriority) return false;

                if (_selectedStatus == 'IN_PROGRESS') {
                  if (t.status != 'IN_PROGRESS') return false;
                } else if (_selectedStatus == 'DUE_SOON') {
                  if (t.status == 'COMPLETED' || t.isBreached) return false;
                  if (t.remainingSlaDuration > const Duration(hours: 2) || t.remainingSlaDuration <= Duration.zero) {
                    return false;
                  }
                } else if (_selectedStatus == 'BREACHED') {
                  if (!t.isBreached) return false;
                } else if (_selectedStatus == 'COMPLETED_TODAY' || _selectedStatus == 'COMPLETED') {
                  if (t.status != 'COMPLETED') return false;
                } else if (_selectedStatus == 'TODO') {
                  if (t.status != 'TODO') return false;
                }

                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                return t.title.toLowerCase().contains(q) ||
                    t.projectOrOfficeCode.toLowerCase().contains(q) ||
                    t.assignedTo.toLowerCase().contains(q) ||
                    t.assignedBy.toLowerCase().contains(q) ||
                    t.priority.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return _buildEmptyState(primaryColor);
              }

              if (isDesktop) {
                return _buildDesktopKanbanBoard(filtered, primaryColor);
              }
              return _buildMobileTaskList(filtered, primaryColor);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('Error loading tasks: $err'),
              ),
            ),
          ),
        ]
        // Tab 1: Daily Clocking View
        else ...[
          const SizedBox(height: 12),
          const ClockingTimelineView(embedded: true),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 20 : 12,
            isDesktop ? 16 : 12,
            isDesktop ? 20 : 12,
            isDesktop ? 40 : 80,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: mainContent,
            ),
          ),
        ),
      ),
      bottomNavigationBar: !isDesktop ? _buildMobileBottomNavBar(primaryColor) : null,
      floatingActionButton: !isDesktop && _activeTab == 0
          ? FloatingActionButton.extended(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () => _openCreateTaskDialog(),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
    );
  }

  Widget _buildDesktopTopHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Module Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment_turned_in_outlined, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tasks & Clocking Management',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),

          // Center: Top Navigation Segmented Control
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopTabItem(
                  index: 0,
                  title: 'Task Tracker',
                  icon: Icons.assignment_outlined,
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 4),
                _buildTopTabItem(
                  index: 1,
                  title: 'Daily Clocking',
                  icon: Icons.timer_outlined,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),

          // Right: Quick Action
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => _openCreateTaskDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabItem({
    required int index,
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? primaryColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactKpiGrid(List<TaskItem> tasks, bool isDesktop) {
    final inProgressCount = tasks.where((t) => t.status == 'IN_PROGRESS').length;
    final dueSoonCount = tasks.where((t) =>
        t.status != 'COMPLETED' &&
        !t.isBreached &&
        t.remainingSlaDuration <= const Duration(hours: 2) &&
        t.remainingSlaDuration > Duration.zero).length;
    final breachedCount = tasks.where((t) => t.isBreached).length;
    final completedCount = tasks.where((t) => t.status == 'COMPLETED').length;

    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildCompactKpiCard(
              title: 'In Progress',
              count: inProgressCount,
              subtitle: 'Running now',
              icon: Icons.play_circle_outline,
              color: const Color(0xFF2563EB),
              filterValue: 'IN_PROGRESS',
              isSelected: _selectedStatus == 'IN_PROGRESS',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildCompactKpiCard(
              title: 'Due Soon',
              count: dueSoonCount,
              subtitle: 'Within 2 hrs',
              icon: Icons.access_time_filled,
              color: const Color(0xFFEA580C),
              filterValue: 'DUE_SOON',
              isSelected: _selectedStatus == 'DUE_SOON',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildCompactKpiCard(
              title: 'Breached',
              count: breachedCount,
              subtitle: 'Needs review',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
              filterValue: 'BREACHED',
              isSelected: _selectedStatus == 'BREACHED',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildCompactKpiCard(
              title: 'Completed',
              count: completedCount,
              subtitle: _selectedDateRange == 'Today' ? 'Today' : _selectedDateRange,
              icon: Icons.check_circle_outline,
              color: const Color(0xFF9CC70A),
              filterValue: 'COMPLETED',
              isSelected: _selectedStatus == 'COMPLETED' || _selectedStatus == 'COMPLETED_TODAY',
            ),
          ),
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildCompactKpiCard(
          title: 'In Progress',
          count: inProgressCount,
          subtitle: 'Running now',
          icon: Icons.play_circle_outline,
          color: const Color(0xFF2563EB),
          filterValue: 'IN_PROGRESS',
          isSelected: _selectedStatus == 'IN_PROGRESS',
        ),
        _buildCompactKpiCard(
          title: 'Due Soon',
          count: dueSoonCount,
          subtitle: 'Within 2 hrs',
          icon: Icons.access_time_filled,
          color: const Color(0xFFEA580C),
          filterValue: 'DUE_SOON',
          isSelected: _selectedStatus == 'DUE_SOON',
        ),
        _buildCompactKpiCard(
          title: 'Breached',
          count: breachedCount,
          subtitle: 'Needs review',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFDC2626),
          filterValue: 'BREACHED',
          isSelected: _selectedStatus == 'BREACHED',
        ),
        _buildCompactKpiCard(
          title: 'Completed',
          count: completedCount,
          subtitle: _selectedDateRange == 'Today' ? 'Today' : _selectedDateRange,
          icon: Icons.check_circle_outline,
          color: const Color(0xFF9CC70A),
          filterValue: 'COMPLETED',
          isSelected: _selectedStatus == 'COMPLETED' || _selectedStatus == 'COMPLETED_TODAY',
        ),
      ],
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String filterValue,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedStatus == filterValue) {
            _selectedStatus = 'All';
          } else {
            _selectedStatus = filterValue;
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(Color primaryColor, bool isDesktop) {
    final employeesAsync = ref.watch(employeesProvider);
    final employees = employeesAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isDesktop
          ? Row(
              children: [
                // 1. Date Range Dropdown
                _buildToolbarDropdown(
                  icon: Icons.calendar_month_outlined,
                  value: _selectedDateRange,
                  items: const [
                    DropdownMenuItem(value: 'Today', child: Text('Today')),
                    DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
                    DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                    DropdownMenuItem(value: 'Last Week', child: Text('Last Week')),
                    DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                    DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                    DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                    DropdownMenuItem(value: 'Custom Range', child: Text('Custom Range...')),
                  ],
                  onChanged: (val) {
                    if (val == 'Custom Range') {
                      _pickCustomDateRange();
                    } else if (val != null) {
                      setState(() {
                        _selectedDateRange = val;
                        _selectedSpecificDay = null;
                        _selectedSpecificMonth = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),

                // 2. Employee Dropdown
                _buildToolbarDropdown(
                  icon: Icons.person_outline,
                  value: _selectedEmployee,
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Employees')),
                    ...employees.map((emp) => DropdownMenuItem(
                          value: emp.employeeId,
                          child: Text('${emp.employeeId} - ${emp.fullName}'),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedEmployee = val);
                  },
                ),
                const SizedBox(width: 8),

                // 3. Priority Dropdown
                _buildToolbarDropdown(
                  icon: Icons.flag_outlined,
                  value: _selectedPriority,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Priority')),
                    DropdownMenuItem(value: 'VERY_HIGH', child: Text('Very High (3h)')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High (8h)')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium (15d)')),
                    DropdownMenuItem(value: 'LOW', child: Text('Low (30d)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPriority = val);
                  },
                ),
                const SizedBox(width: 8),

                // 4. Status Dropdown
                _buildToolbarDropdown(
                  icon: Icons.tune_rounded,
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Status')),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                    DropdownMenuItem(value: 'DUE_SOON', child: Text('Due Soon (2h)')),
                    DropdownMenuItem(value: 'BREACHED', child: Text('Breached SLA')),
                    DropdownMenuItem(value: 'TODO', child: Text('To Do')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(width: 10),

                // 5. Expandable Search Bar
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Search tasks, projects, employees, priority...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildToolbarDropdown(
                        icon: Icons.calendar_month_outlined,
                        value: _selectedDateRange,
                        items: const [
                          DropdownMenuItem(value: 'Today', child: Text('Today')),
                          DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
                          DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                          DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                          DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDateRange = val);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildToolbarDropdown(
                        icon: Icons.tune_rounded,
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Status')),
                          DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                          DropdownMenuItem(value: 'DUE_SOON', child: Text('Due Soon')),
                          DropdownMenuItem(value: 'BREACHED', child: Text('Breached')),
                          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolbarDropdown<T>({
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              isDense: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTimelineBreakdown(List<TaskItem> allTasks, Color primaryColor) {
    final now = DateTime.now();

    // 1. Monthly Day-by-Day breakdown
    if (_selectedDateRange == 'This Month' || _selectedDateRange == 'Last Month') {
      final targetMonth = _selectedDateRange == 'This Month' ? now : DateTime(now.year, now.month - 1, 1);
      final monthName = DateFormat('MMMM yyyy').format(targetMonth);
      final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;

      final monthTasks = allTasks.where((t) => t.assignedAt.year == targetMonth.year && t.assignedAt.month == targetMonth.month).toList();

      final Map<int, int> counts = {};
      for (final t in monthTasks) {
        counts[t.assignedAt.day] = (counts[t.assignedAt.day] ?? 0) + 1;
      }

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      '$monthName (${monthTasks.length} Total Tasks)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                if (_selectedSpecificDay != null)
                  InkWell(
                    onTap: () => setState(() => _selectedSpecificDay = null),
                    child: const Text('Show All Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(daysInMonth, (index) {
                  final day = index + 1;
                  final dayTaskCount = counts[day] ?? 0;
                  final isSelected = _selectedSpecificDay == day;

                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSpecificDay = isSelected ? null : day;
                        });
                      },
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : (dayTaskCount > 0 ? primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : (dayTaskCount > 0 ? primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          '$day ($dayTaskCount)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (dayTaskCount > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Yearly Month-by-Month breakdown
    if (_selectedDateRange == 'This Year') {
      final yearTasks = allTasks.where((t) => t.assignedAt.year == now.year).toList();
      final Map<int, int> monthCounts = {};
      for (final t in yearTasks) {
        monthCounts[t.assignedAt.month] = (monthCounts[t.assignedAt.month] ?? 0) + 1;
      }

      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined, size: 14, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      '${now.year} Annual Breakdown (${yearTasks.length} Total Tasks)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                if (_selectedSpecificMonth != null)
                  InkWell(
                    onTap: () => setState(() => _selectedSpecificMonth = null),
                    child: const Text('Show All Months', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(12, (index) {
                  final monthNum = index + 1;
                  final count = monthCounts[monthNum] ?? 0;
                  final isSelected = _selectedSpecificMonth == monthNum;

                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSpecificMonth = isSelected ? null : monthNum;
                        });
                      },
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : (count > 0 ? primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : (count > 0 ? primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          '${monthNames[index]} ($count)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (count > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_outlined, size: 40, color: primaryColor),
          ),
          const SizedBox(height: 12),
          const Text('No Tasks Found for Selection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Try adjusting the date range, status, employee or priority filter.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildDesktopKanbanBoard(List<TaskItem> tasks, Color primaryColor) {
    final todoTasks = tasks.where((t) => t.status == 'TODO').toList();
    final inProgressTasks = tasks.where((t) => t.status == 'IN_PROGRESS').toList();
    final completedTasks = tasks.where((t) => t.status == 'COMPLETED').toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildKanbanColumn(
            title: 'TODO',
            tasks: todoTasks,
            statusColor: Colors.amber.shade800,
            primaryColor: primaryColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildKanbanColumn(
            title: 'IN PROGRESS',
            tasks: inProgressTasks,
            statusColor: const Color(0xFF2563EB),
            primaryColor: primaryColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildKanbanColumn(
            title: 'COMPLETED',
            tasks: completedTasks,
            statusColor: const Color(0xFF9CC70A),
            primaryColor: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required List<TaskItem> tasks,
    required Color statusColor,
    required Color primaryColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor, letterSpacing: 0.4),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Cards List
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                'No tasks in $title',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildCompactDesktopTaskCard(tasks[index], primaryColor),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTaskList(List<TaskItem> tasks, Color primaryColor) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildCompactDesktopTaskCard(tasks[index], primaryColor),
    );
  }

  Widget _buildCompactDesktopTaskCard(TaskItem task, Color primaryColor) {
    final priorityColor = _getPriorityColor(task.priority);
    final isBreached = task.isBreached;
    final isCompleted = task.status == 'COMPLETED';
    final isInProgress = task.status == 'IN_PROGRESS';
    final isPaused = task.isPaused;

    final startTimeStr = DateFormat('h:mm a').format(task.startTime);
    final endTimeStr = task.endTime != null ? DateFormat('h:mm a').format(task.endTime!) : '';
    final deadlineStr = DateFormat('h:mm a').format(task.deadline);

    return InkWell(
      onTap: () => _openTaskDetailsDialog(task),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBreached ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBreached ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
            width: isBreached ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Project Code + Priority Badge + Status Tag + Action Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF414A51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.projectOrOfficeCode,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        task.priority.replaceAll('_', ' '),
                        style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isInProgress && isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'PAUSED',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ COMPLETED',
                          style: TextStyle(color: Color(0xFF9CC70A), fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                      onPressed: () => _openCreateTaskDialog(task),
                      tooltip: 'Edit Task',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _confirmDeleteTask(task),
                      tooltip: 'Delete Task',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Task Title
            Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isBreached ? const Color(0xFF334155) : const Color(0xFF1E293B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Row 3: Assignee & Assigned by
            Row(
              children: [
                const Icon(Icons.person_outline, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.assignedBy.isNotEmpty ? '${task.assignedTo} · ${task.assignedBy}' : task.assignedTo,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 4: Timing, Duration, and Deadline info
            if (isCompleted) ...[
              Text(
                '$startTimeStr → $endTimeStr · ${_formatWorkedDuration(task.duration)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ] else if (isInProgress) ...[
              Text(
                'Started: $startTimeStr · Due: $deadlineStr · ${_formatWorkedDuration(task.duration)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPaused ? Colors.amber.shade900 : const Color(0xFF2563EB),
                ),
              ),
            ] else ...[
              Text(
                'Assigned: ${DateFormat('dd MMM, h:mm a').format(task.assignedAt)} · Due: $deadlineStr',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 6),

            // Row 5: SLA Status Strip & [View Details] action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isBreached ? Colors.red.shade50 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isBreached ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBreached ? Icons.warning_amber_rounded : (isCompleted ? Icons.check_circle : Icons.schedule),
                        size: 12,
                        color: isBreached ? Colors.red.shade700 : (isCompleted ? primaryColor : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBreached
                            ? 'BREACHED BY ${task.formattedBreachDuration.toUpperCase()}'
                            : (isCompleted ? '✓ Completed on time' : '${task.formattedRemainingSla} left'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isBreached ? Colors.red.shade700 : (isCompleted ? primaryColor : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _openTaskDetailsDialog(task),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 13, color: primaryColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTask(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Task'),
          ],
        ),
        content: Text('Are you sure you want to delete "${task.title}" (${task.projectOrOfficeCode}) assigned to ${task.assignedTo}?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(taskRepositoryProvider);
      await repo.deleteTask(task.id);
      ref.invalidate(tasksProvider);
      ref.invalidate(taskProjectHoursProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${task.title}" deleted successfully'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildMobileBottomNavBar(Color primaryColor) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 0 ? primaryColor : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 22,
                      color: _activeTab == 0 ? primaryColor : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Task Tracker',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _activeTab == 0 ? primaryColor : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 1 ? primaryColor : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 22,
                      color: _activeTab == 1 ? primaryColor : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily Clocking',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _activeTab == 1 ? primaryColor : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWorkedDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
