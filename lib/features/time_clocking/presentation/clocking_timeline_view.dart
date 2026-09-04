import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/clock_entry.dart';
import '../providers/clocking_providers.dart';
import 'clock_action_widget.dart';

class ClockingTimelineView extends ConsumerStatefulWidget {
  const ClockingTimelineView({
    super.key,
    this.employeeId,
    this.embedded = false,
  });

  final String? employeeId;
  final bool embedded;

  @override
  ConsumerState<ClockingTimelineView> createState() => _ClockingTimelineViewState();
}

class _ClockingTimelineViewState extends ConsumerState<ClockingTimelineView> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  String _selectedActivity = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.employeeId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Employee? _findEmployee(String empId, List<Employee> employees) {
    if (empId.isEmpty) return null;
    final normalizedSearch = empId.toLowerCase().trim();
    for (final emp in employees) {
      if (emp.employeeId.toLowerCase() == normalizedSearch ||
          'emp-${emp.id}'.toLowerCase() == normalizedSearch ||
          emp.id.toString() == normalizedSearch) {
        return emp;
      }
    }
    final numOnly = empId.replaceAll(RegExp(r'[^0-9]'), '');
    if (numOnly.isNotEmpty) {
      final parsedId = int.tryParse(numOnly);
      if (parsedId != null) {
        for (final emp in employees) {
          if (emp.id == parsedId) return emp;
        }
      }
    }
    return null;
  }

  Color _getActivityColor(String activity) {
    final lower = activity.toLowerCase();
    if (lower.contains('work') || lower.contains('general')) {
      return const Color(0xFF2563EB);
    } else if (lower.contains('meeting')) {
      return const Color(0xFF7C3AED);
    } else if (lower.contains('lunch') || lower.contains('tea') || lower.contains('break')) {
      return const Color(0xFFEA580C);
    } else if (lower.contains('client') || lower.contains('task')) {
      return const Color(0xFF0D9488);
    } else if (lower.contains('site')) {
      return const Color(0xFF9CC70A);
    } else {
      return const Color(0xFF414A51);
    }
  }

  IconData _getActivityIcon(String activity) {
    final lower = activity.toLowerCase();
    if (lower.contains('work')) return Icons.work_outline;
    if (lower.contains('meeting')) return Icons.groups_outlined;
    if (lower.contains('lunch')) return Icons.restaurant_outlined;
    if (lower.contains('tea') || lower.contains('break')) return Icons.coffee_outlined;
    if (lower.contains('client') || lower.contains('task')) return Icons.task_alt_outlined;
    if (lower.contains('site')) return Icons.location_on_outlined;
    return Icons.timer_outlined;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF9CC70A);
    const secondaryColor = Color(0xFF414A51);

    final employeesAsync = ref.watch(employeesProvider);
    final allEmployees = employeesAsync.valueOrNull ?? [];

    final clockEntriesAsync = ref.watch(
      clockEntriesProvider((
        employeeId: _selectedEmployeeId,
        date: _selectedDate,
      )),
    );
    final activeEntriesAsync = ref.watch(allActiveClockEntriesProvider);

    final entries = clockEntriesAsync.valueOrNull ?? [];
    final activeEntries = activeEntriesAsync.valueOrNull ?? [];

    final filteredEntries = entries.where((entry) {
      if (_selectedActivity != 'All' && entry.entryType != _selectedActivity) {
        return false;
      }
      if (_selectedStatus == 'Active' && !entry.isActive) return false;
      if (_selectedStatus == 'Completed' && entry.isActive) return false;

      if (_searchQuery.isNotEmpty) {
        final emp = _findEmployee(entry.employeeId, allEmployees);
        final empName = emp?.fullName.toLowerCase() ?? '';
        final empCode = emp?.employeeId.toLowerCase() ?? '';
        final notesStr = entry.notes?.toLowerCase() ?? '';
        final typeStr = entry.entryType.toLowerCase();

        if (!empName.contains(_searchQuery) &&
            !empCode.contains(_searchQuery) &&
            !notesStr.contains(_searchQuery) &&
            !typeStr.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalClockings = filteredEntries.length;
    final activeCount = activeEntries.length;
    double workHours = 0.0;
    double breakHours = 0.0;

    for (final e in filteredEntries) {
      if (e.isBreak) {
        breakHours += e.durationInHours;
      } else {
        workHours += e.durationInHours;
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 750;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) ...[
          ClockActionWidget(
            employeeId: _selectedEmployeeId!,
            onClockChanged: () {
              ref.invalidate(clockEntriesProvider);
              ref.invalidate(allActiveClockEntriesProvider);
              ref.invalidate(totalWorkHoursProvider);
              ref.invalidate(totalBreakHoursProvider);
            },
          ),
          const SizedBox(height: 16),
        ],

        // KPI Summary Cards Banner
        _buildKpiBanner(
          totalClockings: totalClockings,
          activeCount: activeCount,
          workHours: workHours,
          breakHours: breakHours,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isMobile: isMobile,
        ),
        const SizedBox(height: 16),

        // Live Active Activities Overview Section
        _buildActiveActivitiesSection(activeEntries, allEmployees, primaryColor, isMobile),
        const SizedBox(height: 16),

        // Controls Toolbar (Date, Employee, Activity Filter, Search)
        _buildControlToolbar(allEmployees, isMobile),
        const SizedBox(height: 16),

        // Daily Clockings Data Table / Mobile Card List
        _buildClockingsTable(filteredEntries, allEmployees, primaryColor, secondaryColor, isMobile),
      ],
    );

    if (widget.embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: content,
      ),
    );
  }

  // --- KPI BANNER ---

  Widget _buildKpiBanner({
    required int totalClockings,
    required int activeCount,
    required double workHours,
    required double breakHours,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isMobile,
  }) {
    final items = [
      _KpiData(
        label: 'Date Clockings',
        value: '$totalClockings',
        subtext: DateFormat('dd MMM yyyy').format(_selectedDate),
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        icon: Icons.calendar_today_outlined,
      ),
      _KpiData(
        label: 'Active Staff Now',
        value: '$activeCount',
        subtext: 'Currently clocked in',
        iconColor: primaryColor,
        bgColor: const Color(0xFFF7FEE7),
        icon: Icons.play_circle_outline,
      ),
      _KpiData(
        label: 'Productive Work',
        value: '${workHours.toStringAsFixed(1)} hrs',
        subtext: 'General Work & Tasks',
        iconColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFCCFBF1),
        icon: Icons.work_outline,
      ),
      _KpiData(
        label: 'Breaks Logged',
        value: '${breakHours.toStringAsFixed(1)} hrs',
        subtext: 'Lunch & Tea Breaks',
        iconColor: secondaryColor,
        bgColor: const Color(0xFFF1F5F9),
        icon: Icons.coffee_outlined,
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildKpiCard(items[index]),
      );
    }

    return Row(
      children: items.map((kpi) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildKpiCard(kpi)))).toList(),
    );
  }

  Widget _buildKpiCard(_KpiData kpi) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kpi.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kpi.icon, color: kpi.iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      kpi.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kpi.subtext,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- LIVE ACTIVE ACTIVITIES SECTION ---

  Widget _buildActiveActivitiesSection(
    List<ClockEntry> activeEntries,
    List<Employee> allEmployees,
    Color primaryColor,
    bool isMobile,
  ) {
    if (activeEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No employees are currently clocked into an active activity right now.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Active Staff (${activeEntries.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Running Activities',
                style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: activeEntries.map((entry) {
              final emp = _findEmployee(entry.employeeId, allEmployees);
              final empName = emp != null ? emp.fullName : (entry.employeeId.isNotEmpty ? entry.employeeId : 'Employee');
              final startTimeStr = DateFormat('HH:mm').format(entry.startTime);
              final color = _getActivityColor(entry.entryType);

              return Container(
                width: isMobile ? double.infinity : 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(
                        empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.entryType,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$startTimeStr → Running',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined, color: Colors.red, size: 22),
                      tooltip: 'Clock Out Employee',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clock Out Employee'),
                            content: Text('Stop active activity (${entry.entryType}) for $empName?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Clock Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final repo = ref.read(clockingRepositoryProvider);
                          await repo.adminClockOutEntry(entry.id, DateTime.now());
                          ref.invalidate(clockEntriesProvider);
                          ref.invalidate(allActiveClockEntriesProvider);
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- CONTROL TOOLBAR ---

  Widget _buildControlToolbar(List<Employee> allEmployees, bool isMobile) {
    final activityTypes = ['All', 'General Work', 'Meeting', 'Lunch Break', 'Tea Break', 'Client Website Task', 'Site Visit', 'Idle'];
    final statusTypes = ['All', 'Active', 'Completed'];

    Widget dateNav = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );

    Widget employeeDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedEmployeeId,
          isExpanded: true,
          hint: const Text('All Employees', style: TextStyle(fontSize: 12)),
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Employees', style: TextStyle(fontSize: 12)),
            ),
            ...allEmployees.map((emp) {
              return DropdownMenuItem<String?>(
                value: emp.employeeId.isNotEmpty ? emp.employeeId : 'EMP-${emp.id}',
                child: Text(
                  '${emp.fullName} (${emp.employeeId.isNotEmpty ? emp.employeeId : "EMP${emp.id}"})',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (val) => setState(() => _selectedEmployeeId = val),
        ),
      ),
    );

    Widget activityDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedActivity,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: activityTypes.map((act) {
            return DropdownMenuItem<String>(
              value: act,
              child: Text(act == 'All' ? 'All Activities' : act, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedActivity = val);
          },
        ),
      ),
    );

    Widget statusDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: statusTypes.map((st) {
            return DropdownMenuItem<String>(
              value: st,
              child: Text(st == 'All' ? 'All Statuses' : st, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedStatus = val);
          },
        ),
      ),
    );

    Widget searchBox = SizedBox(
      width: isMobile ? double.infinity : 160,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search clockings...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
      ),
    );

    Widget refreshBtn = IconButton(
      icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
      tooltip: 'Refresh Data',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () {
        ref.invalidate(clockEntriesProvider);
        ref.invalidate(allActiveClockEntriesProvider);
      },
    );

    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: dateNav),
                const SizedBox(width: 8),
                refreshBtn,
              ],
            ),
            const SizedBox(height: 8),
            employeeDropdown,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: activityDropdown),
                const SizedBox(width: 8),
                Expanded(child: statusDropdown),
              ],
            ),
            const SizedBox(height: 8),
            searchBox,
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          dateNav,
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 180, child: employeeDropdown),
              SizedBox(width: 140, child: activityDropdown),
              SizedBox(width: 130, child: statusDropdown),
              searchBox,
              refreshBtn,
            ],
          ),
        ],
      ),
    );
  }

  // --- DAILY CLOCKINGS TABLE / MOBILE CARDS ---

  Widget _buildClockingsTable(
    List<ClockEntry> entries,
    List<Employee> allEmployees,
    Color primaryColor,
    Color secondaryColor,
    bool isMobile,
  ) {
    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.timer_off_outlined, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'No clocking records found for the selected criteria.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569)),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing the date, employee, or activity filters.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: entries.map((entry) {
          final emp = _findEmployee(entry.employeeId, allEmployees);
          final empName = emp != null ? emp.fullName : (entry.employeeId.isNotEmpty ? entry.employeeId : 'Unassigned');
          final empDept = emp?.department ?? 'Staff';
          final color = _getActivityColor(entry.entryType);
          final icon = _getActivityIcon(entry.entryType);

          final startTimeStr = DateFormat('HH:mm').format(entry.startTime);
          final endTimeStr = entry.endTime != null ? DateFormat('HH:mm').format(entry.endTime!) : 'Running';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              empName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              empDept,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            entry.entryType,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$startTimeStr → $endTimeStr',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    Text(
                      entry.formattedDuration,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: entry.isActive ? const Color(0xFF16A34A) : color,
                      ),
                    ),
                  ],
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.notes!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
                if (entry.isActive) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.stop, size: 14),
                      label: const Text('Clock Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final repo = ref.read(clockingRepositoryProvider);
                        await repo.adminClockOutEntry(entry.id, DateTime.now());
                        ref.invalidate(clockEntriesProvider);
                        ref.invalidate(allActiveClockEntriesProvider);
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('End Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('Notes / Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
          ],
          rows: entries.map((entry) {
            final emp = _findEmployee(entry.employeeId, allEmployees);
            final empName = emp != null ? emp.fullName : (entry.employeeId.isNotEmpty ? entry.employeeId : 'Unassigned');
            final empDept = emp?.department ?? 'Staff';
            final color = _getActivityColor(entry.entryType);
            final icon = _getActivityIcon(entry.entryType);

            final startTimeStr = DateFormat('HH:mm').format(entry.startTime);
            final endTimeStr = entry.endTime != null ? DateFormat('HH:mm').format(entry.endTime!) : 'Active';

            return DataRow(
              cells: [
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            empName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            empDept,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Text(
                          entry.entryType,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    startTimeStr,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
                DataCell(
                  entry.isActive
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Running',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          endTimeStr,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
                        ),
                ),
                DataCell(
                  Text(
                    entry.formattedDuration,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: entry.isActive ? const Color(0xFF16A34A) : color,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      entry.notes ?? '-',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  entry.isActive
                      ? TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.stop, size: 14),
                          label: const Text('Clock Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final repo = ref.read(clockingRepositoryProvider);
                            await repo.adminClockOutEntry(entry.id, DateTime.now());
                            ref.invalidate(clockEntriesProvider);
                            ref.invalidate(allActiveClockEntriesProvider);
                          },
                        )
                      : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.subtext,
    required this.iconColor,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtext;
  final Color iconColor;
  final Color bgColor;
  final IconData icon;
}
