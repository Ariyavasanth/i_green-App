import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/on_duty_assignment.dart';
import '../domain/on_duty_site.dart';
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

  String _formatStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'TRAVELING_TO_DESTINATION':
        return 'Traveling to Site';
      case 'REACHED_DESTINATION':
        return 'Arrived at site';
      case 'WORK_COMPLETED':
        return 'OD work completed';
      case 'RETURNING_TO_OFFICE':
        return 'Return office from site';
      case 'IN_PROGRESS':
      case 'ACTIVE':
        return 'In Progress';
      case 'ASSIGNED':
        return 'Assigned';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
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
              100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        padding: const EdgeInsets.only(bottom: 16),
                        child: EmployeeOnDutyCard(assignment: activeOD),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

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
          'Apply OD',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(List<OnDutyAssignment> list, bool isMobile) {
    final total = list.length;
    final inProgress = list.where((x) => x.isOngoing && x.status != 'ASSIGNED').length;
    final assigned = list.where((x) => x.status == 'ASSIGNED').length;
    final completed = list.where((x) => x.status == 'COMPLETED').length;

    final cards = [
      _buildStatCard('Total ODs', total.toString(), Icons.assignment_outlined, const Color(0xFF414A51)),
      _buildStatCard('Assigned', assigned.toString(), Icons.schedule, const Color(0xFF3B82F6)),
      _buildStatCard('Active / En Route', inProgress.toString(), Icons.pending_actions, const Color(0xFFF59E0B)),
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
    final statusLabel = item.effectiveStatusLabel;
    final statusColor = _getStatusColor(item);

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
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
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
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              item.date,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                            if (item.actualStartTime != null && item.actualStartTime!.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                item.actualStartTime!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              if (item.actualEndTime != null && item.actualEndTime!.isNotEmpty) ...[
                                Text(' - ${item.actualEndTime}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              ],
                            ] else if (item.plannedStartTime.isNotEmpty) ...[
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
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (item.effectiveReachedPhoto != null || item.effectiveWorkPhoto != null)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.photo_camera_rounded, size: 16, color: Color(0xFF16A34A)),
                          ),
                        if (item.effectiveDestinationLatitude != null && item.effectiveDestinationLongitude != null)
                          IconButton(
                            icon: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF414A51)),
                            tooltip: 'View Destination on Map',
                            onPressed: () => _openMap(item.effectiveDestinationLatitude!, item.effectiveDestinationLongitude!),
                          )
                        else if (item.startLatitude != null && item.startLongitude != null)
                          IconButton(
                            icon: const Icon(Icons.map_outlined, size: 18, color: Color(0xFF414A51)),
                            tooltip: 'View Start Location',
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

  Color _getStatusColor(OnDutyAssignment item) {
    final s = item.status.toUpperCase();
    if (s == 'COMPLETED') return const Color(0xFF10B981);
    if (s == 'RETURNING_TO_OFFICE' || (item.returnStartTime != null && item.officeReachedTime == null)) {
      return const Color(0xFF3B82F6);
    }
    if (s == 'WORK_COMPLETED' || (item.workCompletedTime != null && item.returnStartTime == null)) {
      return const Color(0xFF414A51);
    }
    if (s == 'REACHED_DESTINATION' || (item.reachedTime != null && item.workCompletedTime == null)) {
      return const Color(0xFF16A34A);
    }
    if (s == 'TRAVELING_TO_DESTINATION' || (item.travelStartTime != null && item.reachedTime == null)) {
      return const Color(0xFFD97706);
    }
    if (s == 'ASSIGNED') return const Color(0xFF3B82F6);
    if (s == 'CANCELLED') return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
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
    final displaySites = item.sites.isNotEmpty
        ? item.sites
        : [
            OnDutySite(
              siteId: '1',
              siteName: item.destinationName.isNotEmpty ? item.destinationName : item.destination,
              purpose: item.purpose,
              destination: item.destination,
              destinationAddress: item.destinationAddress,
              radius: item.destinationRadius,
              status: item.isCompleted ? 'COMPLETED' : item.status,
              reachedTime: item.reachedTime,
              reachedPhoto: item.effectiveReachedPhoto,
              workCompletedTime: item.workCompletedTime,
              workPhoto: item.effectiveWorkPhoto,
            ),
          ];

    final statusColor = _getStatusColor(item);
    final statusLabel = _formatStatusLabel(item.status);

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header Banner
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9CC70A).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.business_center, color: Color(0xFF414A51), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.odType,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.odType} • ${item.date}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, size: 22, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // OD SUMMARY
                      const Text(
                        'OD SUMMARY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3-Column Summary Card Grid
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${displaySites.length} ${displaySites.length == 1 ? "Site" : "Sites"}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Visits', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(height: 28, width: 1, color: const Color(0xFFCBD5E1)),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        item.isCompleted ? Icons.check_circle : Icons.pie_chart_outline,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: statusColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Status', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(height: 28, width: 1, color: const Color(0xFFCBD5E1)),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    item.durationMinutes > 0
                                        ? '${item.durationMinutes} min'
                                        : (item.actualStartTime?.isNotEmpty == true
                                            ? item.actualStartTime!
                                            : (item.plannedStartTime.isNotEmpty ? item.plannedStartTime : '--')),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.durationMinutes > 0 ? 'Duration' : 'Start Time',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (item.purpose.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Purpose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          item.purpose,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],

                      if (item.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Instructions / Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          item.notes,
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // SITE VISITS Section Header
                      const Text(
                        'SITE VISITS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Vertical Timeline for Sites
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displaySites.length,
                        itemBuilder: (context, idx) {
                          final site = displaySites[idx];
                          final isLast = idx == displaySites.length - 1;

                          return _buildTimelineSiteCard(
                            context: ctx,
                            site: site,
                            siteIndex: idx + 1,
                            isLastSite: isLast,
                            assignment: item,
                          );
                        },
                      ),

                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // RETURN TO OFFICE Section
                      _buildReturnToOfficeSection(item),

                      const SizedBox(height: 20),

                      // Bottom Close Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9CC70A),
                            foregroundColor: const Color(0xFF414A51),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineSiteCard({
    required BuildContext context,
    required OnDutySite site,
    required int siteIndex,
    required bool isLastSite,
    OnDutyAssignment? assignment,
  }) {
    final bool isCompleted = site.isCompleted;
    final Color nodeColor = isCompleted
        ? const Color(0xFF16A34A)
        : (site.isReached ? const Color(0xFF3B82F6) : (site.isTraveling ? const Color(0xFFD97706) : const Color(0xFF94A3B8)));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline node + connecting vertical line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : Text(
                            '$siteIndex',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Main Site Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFF0FDF4).withValues(alpha: 0.5) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Site Name + Status Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            site.effectiveName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCompleted) ...[
                                const Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                site.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (site.purpose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(site.purpose, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    ],

                    if (site.destinationAddress.isNotEmpty || site.destination.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              site.destinationAddress.isNotEmpty ? site.destinationAddress : site.destination,
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.radar_outlined, size: 13, color: Color(0xFF414A51)),
                        const SizedBox(width: 4),
                        Text(
                          'Geofence Radius: ${site.radius}m',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF414A51)),
                        ),
                      ],
                    ),

                    // Timings Bar
                    if (site.reachedTime != null || site.workCompletedTime != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            if (site.reachedTime != null) ...[
                              Icon(Icons.login, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                site.reachedTime!,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 4),
                              Text('Arrived', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                            if (site.reachedTime != null && site.workCompletedTime != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('→', style: TextStyle(color: Colors.grey)),
                              ),
                            if (site.workCompletedTime != null) ...[
                              Icon(Icons.task_alt, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                site.workCompletedTime!,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 4),
                              Text('Completed', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ),
                    ],

                    _buildSiteLocationProofsBox(site: site, siteIndex: siteIndex, assignment: assignment),

                    // Photo Proof Thumbnails
                    if (site.reachedPhoto != null || site.workPhoto != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (site.reachedPhoto != null)
                            Expanded(
                              child: _buildPhotoThumbnail(context, 'Arrival Proof', site.reachedPhoto!),
                            ),
                          if (site.reachedPhoto != null && site.workPhoto != null)
                            const SizedBox(width: 10),
                          if (site.workPhoto != null)
                            Expanded(
                              child: _buildPhotoThumbnail(context, 'Work Proof', site.workPhoto!),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteLocationProofsBox({
    required OnDutySite site,
    required int siteIndex,
    OnDutyAssignment? assignment,
  }) {
    final startLat = site.startLatitude ?? (siteIndex == 1 ? assignment?.startTripLatitude ?? assignment?.startLatitude : null);
    final startLng = site.startLongitude ?? (siteIndex == 1 ? assignment?.startTripLongitude ?? assignment?.startLongitude : null);

    final reachedLat = site.reachedLatitude ?? (siteIndex == 1 ? assignment?.reachedLatitude : null);
    final reachedLng = site.reachedLongitude ?? (siteIndex == 1 ? assignment?.reachedLongitude : null);

    final endLat = site.workEndLatitude ?? (siteIndex == 1 ? assignment?.workEndLatitude : null);
    final endLng = site.workEndLongitude ?? (siteIndex == 1 ? assignment?.workEndLongitude : null);

    final hasAnyLocation = (startLat != null && startLng != null) ||
        (reachedLat != null && reachedLng != null) ||
        (endLat != null && endLng != null);

    if (!hasAnyLocation) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, size: 13, color: Color(0xFF414A51)),
              SizedBox(width: 4),
              Text(
                'STAGE GPS LOCATIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF414A51),
                ),
              ),
            ],
          ),
          if (startLat != null && startLng != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.navigation_outlined, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Started Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      Text(
                        '${startLat.toStringAsFixed(5)}, ${startLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(startLat, startLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (reachedLat != null && reachedLng != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reached Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                      Text(
                        '${reachedLat.toStringAsFixed(5)}, ${reachedLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(reachedLat, reachedLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (endLat != null && endLng != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Completed Location',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                      Text(
                        '${endLat.toStringAsFixed(5)}, ${endLng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openMap(endLat, endLng),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text('Map', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnToOfficeSection(OnDutyAssignment item) {
    final bool isCheckoutDirect = item.afterCompletionOption == 'CHECKOUT_FROM_OD';
    final bool hasReturned = item.officeReachedTime != null || item.actualEndTime != null || item.isCompleted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: hasReturned ? const Color(0xFF16A34A) : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasReturned ? Icons.check : (isCheckoutDirect ? Icons.logout : Icons.business),
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCheckoutDirect ? 'OD DIRECT CHECK-OUT' : 'RETURN TO OFFICE',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  if (hasReturned) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isCheckoutDirect
                                ? 'Completed & Checked out directly from OD'
                                : 'Returned to office${item.officeReachedTime != null ? " at ${item.officeReachedTime}" : (item.actualEndTime != null ? " at ${item.actualEndTime}" : "")}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.pending_actions, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isCheckoutDirect ? 'Check-out pending after completion' : 'Return to office pending',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Trip Status: ${_formatStatusLabel(item.status)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(BuildContext context, String label, String photoStr) {
    Widget imageWidget;
    try {
      if (photoStr.startsWith('data:image/')) {
        final clean = photoStr.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        imageWidget = Image.memory(base64Decode(clean), fit: BoxFit.cover);
      } else if (photoStr.startsWith('http')) {
        imageWidget = Image.network(photoStr, fit: BoxFit.cover);
      } else {
        imageWidget = Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 24)),
        );
      }
    } catch (_) {
      imageWidget = Container(
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 24)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showImagePreviewDialog(context, photoStr),
          child: Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                children: [
                  Positioned.fill(child: imageWidget),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePreviewDialog(BuildContext context, String photoStr) {
    Widget img;
    try {
      if (photoStr.startsWith('data:image/')) {
        final clean = photoStr.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
        img = Image.memory(base64Decode(clean), fit: BoxFit.contain);
      } else if (photoStr.startsWith('http')) {
        img = Image.network(photoStr, fit: BoxFit.contain);
      } else {
        img = const Icon(Icons.broken_image, color: Colors.white, size: 64);
      }
    } catch (_) {
      img = const Icon(Icons.broken_image, color: Colors.white, size: 64);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
