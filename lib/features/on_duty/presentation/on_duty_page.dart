import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/on_duty_assignment.dart';
import '../providers/on_duty_providers.dart';
import 'assign_on_duty_dialog.dart';
import 'employee_on_duty_card.dart';

class OnDutyPage extends ConsumerStatefulWidget {
  const OnDutyPage({super.key});

  @override
  ConsumerState<OnDutyPage> createState() => _OnDutyPageState();
}

class _OnDutyPageState extends ConsumerState<OnDutyPage> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  static const _statusFilters = ['All', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final query = '$latitude,$longitude';
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  void _openRequestOdDialog(Employee currentEmp) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AssignOnDutyDialog(
        preSelectedEmployee: currentEmp,
        isSelfRequest: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);
    final isMobile = MediaQuery.of(context).size.width < 750;

    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
        ),
      );
    }

    final dateStr = _selectedDate != null ? DateFormat('dd-MM-yyyy').format(_selectedDate!) : null;
    final assignmentsAsync = ref.watch(
      allOnDutyAssignmentsProvider((
        date: dateStr,
        statusFilter: _selectedStatus == 'All' ? null : _selectedStatus,
        employeeId: currentEmp.id,
      )),
    );

    final activeOnDutyAsync = ref.watch(activeOnDutyAssignmentProvider(currentEmp.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFF9CC70A),
          onRefresh: () async {
            ref.invalidate(allOnDutyAssignmentsProvider);
            ref.invalidate(activeOnDutyAssignmentProvider(currentEmp.id));
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 24,
              isMobile ? 12 : 20,
              isMobile ? 12 : 24,
              80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                _buildHeader(currentEmp, isMobile),
                const SizedBox(height: 16),

                // KPI Stat Cards
                assignmentsAsync.when(
                  data: (list) => _buildKpiGrid(list, isMobile),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Active Live On-Duty Card
                activeOnDutyAsync.when(
                  data: (activeOD) {
                    if (activeOD != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: EmployeeOnDutyCard(assignment: activeOD),
                      );
                    }
                    return _buildEmptyActiveOdCard(currentEmp, isMobile);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => _buildEmptyActiveOdCard(currentEmp, isMobile),
                ),
                const SizedBox(height: 12),

                // Filter & Search Controls
                _buildFilterBar(isMobile),
                const SizedBox(height: 16),

                // History / Assignments List
                assignmentsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Error loading On-Duty records: $err'),
                    ),
                  ),
                  data: (assignments) {
                    final filtered = assignments.where((item) {
                      if (_searchQuery.trim().isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      return item.purpose.toLowerCase().contains(q) ||
                          item.destination.toLowerCase().contains(q) ||
                          item.odType.toLowerCase().contains(q) ||
                          item.notes.toLowerCase().contains(q);
                    }).toList();

                    if (filtered.isEmpty) {
                      return _buildEmptyListState();
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildAssignmentCard(filtered[i], currentEmp, isMobile),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequestOdDialog(currentEmp),
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: const Color(0xFF414A51),
        elevation: 4,
        icon: const Icon(Icons.add_task, size: 20),
        label: const Text(
          'Request On-Duty',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildHeader(Employee currentEmp, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.business_center_outlined,
              color: Color(0xFF414A51),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'On-Duty (OD)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'View admin-assigned tasks and submit your On-Duty requests.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () => _openRequestOdDialog(currentEmp),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Request On-Duty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(List<OnDutyAssignment> list, bool isMobile) {
    final total = list.length;
    final inProgress = list.where((x) => x.status == 'IN_PROGRESS' || x.status == 'ACTIVE').length;
    final assigned = list.where((x) => x.status == 'ASSIGNED').length;
    final completed = list.where((x) => x.status == 'COMPLETED').length;

    final cards = [
      _buildStatCard('Total ODs', total.toString(), Icons.assignment_outlined, const Color(0xFF414A51)),
      _buildStatCard('Assigned', assigned.toString(), Icons.schedule, const Color(0xFF3B82F6)),
      _buildStatCard('In Progress', inProgress.toString(), Icons.pending_actions, const Color(0xFFF59E0B)),
      _buildStatCard('Completed', completed.toString(), Icons.task_alt, const Color(0xFF10B981)),
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: cards,
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveOdCard(Employee currentEmp, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9CC70A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pin_drop_outlined, color: Color(0xFF414A51), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Active On-Duty In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Are you heading out for official client visit or field work? Request or start an On-Duty.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openRequestOdDialog(currentEmp),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Apply OD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: const Color(0xFF414A51),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Purpose, Destination, Type...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedDate != null ? const Color(0xFF9CC70A).withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedDate != null ? const Color(0xFF9CC70A) : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: _selectedDate != null ? const Color(0xFF414A51) : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedDate != null ? DateFormat('dd MMM yyyy').format(_selectedDate!) : 'All Dates',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedDate != null ? const Color(0xFF414A51) : Colors.grey.shade700,
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedDate = null),
                          child: const Icon(Icons.close, size: 14, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((st) {
                final isSelected = _selectedStatus == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      st == 'All' ? 'All Status' : st.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF414A51) : Colors.grey.shade700,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF9CC70A).withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF9CC70A) : Colors.grey.shade300,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedStatus = st);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(OnDutyAssignment item, Employee currentEmp, bool isMobile) {
    final statusColor = _getStatusColor(item.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetailsDialog(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_center, size: 14, color: Color(0xFF414A51)),
                          const SizedBox(width: 4),
                          Text(
                            item.odType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF414A51),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'By: ${item.assignedBy}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.status.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.purpose,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.destination,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          item.date,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          item.plannedStartTime,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        if (item.plannedEndTime != null && item.plannedEndTime!.isNotEmpty) ...[
                          Text(' - ${item.plannedEndTime}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (item.startLatitude != null && item.startLongitude != null)
                          IconButton(
                            icon: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF414A51)),
                            tooltip: 'View Location',
                            onPressed: () => _openMap(item.startLatitude!, item.startLongitude!),
                          ),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
      case 'ACTIVE':
        return const Color(0xFFF59E0B);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'ASSIGNED':
        return const Color(0xFF3B82F6);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildEmptyListState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No On-Duty Records Found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            'You have no assigned or requested On-Duty tasks matching your filters.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(OnDutyAssignment item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.business_center, color: Color(0xFF414A51), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.odType,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Purpose', item.purpose),
              _buildDetailRow('Destination', item.destination),
              _buildDetailRow('Date', item.date),
              _buildDetailRow('Planned Time', '${item.plannedStartTime}${item.plannedEndTime != null ? " - ${item.plannedEndTime}" : ""}'),
              if (item.actualStartTime != null) _buildDetailRow('Actual Start Time', item.actualStartTime!),
              if (item.actualEndTime != null) _buildDetailRow('Actual End Time', item.actualEndTime!),
              if (item.durationMinutes > 0) _buildDetailRow('Total Duration', '${item.durationMinutes} Minutes'),
              _buildDetailRow('Status', item.status),
              _buildDetailRow('Assigned By', item.assignedBy),
              if (item.afterCompletionOption.isNotEmpty)
                _buildDetailRow('After Completion', item.afterCompletionOption == 'CHECKOUT_FROM_OD' ? 'Check-out directly from OD' : 'Return to Office'),
              if (item.notes.isNotEmpty) _buildDetailRow('Notes / Instructions', item.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
