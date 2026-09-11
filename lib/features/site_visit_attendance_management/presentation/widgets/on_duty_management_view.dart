import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../on_duty/domain/on_duty_assignment.dart';
import '../../../on_duty/domain/on_duty_site.dart';
import '../../../on_duty/providers/on_duty_providers.dart';
import '../../../on_duty/presentation/assign_on_duty_dialog.dart';

class OnDutyManagementView extends ConsumerStatefulWidget {
  const OnDutyManagementView({super.key});

  @override
  ConsumerState<OnDutyManagementView> createState() => _OnDutyManagementViewState();
}

class _OnDutyManagementViewState extends ConsumerState<OnDutyManagementView> {
  String _searchQuery = '';
  String _selectedStatus = 'All';
  DateTime _selectedDate = DateTime.now();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openMap(double latitude, double longitude, {String label = ''}) async {
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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final assignmentsAsync = ref.watch(
      allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null)),
    );

    return RefreshIndicator(
      color: const Color(0xFF9CC70A),
      onRefresh: () async {
        ref.invalidate(allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null)));
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streamlined Filters Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full-width Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Employee / Purpose...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Status & Date Selectors Side-by-Side
                Row(
                  children: [
                    // Status Dropdown
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF414A51), fontWeight: FontWeight.w500),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('Status: All')),
                              DropdownMenuItem(value: 'ASSIGNED', child: Text('🟡 Assigned')),
                              DropdownMenuItem(value: 'IN_PROGRESS', child: Text('🔵 Running')),
                              DropdownMenuItem(value: 'COMPLETED', child: Text('🟢 Completed')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Date Selector Button
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF414A51)),
                          label: Text(
                            dateStr,
                            style: const TextStyle(color: Color(0xFF414A51), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Assignments Table
            assignmentsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                ),
              ),
              error: (e, _) => Center(child: Text('Error loading On-Duty assignments: $e')),
              data: (allAssignments) {
                final filtered = allAssignments.where((item) {
                  final matchSearch = _searchQuery.isEmpty ||
                      item.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      item.purpose.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      item.odType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      item.destination.toLowerCase().contains(_searchQuery.toLowerCase());

                  final statusUpper = item.status.toUpperCase();
                  final matchStatus = _selectedStatus == 'All' ||
                      statusUpper == _selectedStatus ||
                      (_selectedStatus == 'IN_PROGRESS' && statusUpper == 'ACTIVE');

                  return matchSearch && matchStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No On-Duty records found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF414A51)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No on-duty records found for this date',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 768;

                  if (isMobile) {
                    return Column(
                      children: filtered.map((item) => _buildMobileCard(item)).toList(),
                    );
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF414A51),
                            fontSize: 13,
                          ),
                          dataRowMinHeight: 52,
                          columns: const [
                            DataColumn(label: Text('Employee')),
                            DataColumn(label: Text('OD Type')),
                            DataColumn(label: Text('Destination')),
                            DataColumn(label: Text('Planned Time')),
                            DataColumn(label: Text('Actual Start')),
                            DataColumn(label: Text('Actual End')),
                            DataColumn(label: Text('Duration')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered.map((item) {
                            final durationStr = item.durationMinutes > 0
                                ? '${item.durationMinutes ~/ 60}h ${item.durationMinutes % 60}m'
                                : (item.status == 'IN_PROGRESS' || item.status == 'ACTIVE' ? 'Running' : '--');

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item.employeeName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.odType,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.sites.isNotEmpty
                                        ? '📍 Sites (${item.sites.length}): ${item.sites.map((s) => s.effectiveName).join(" → ")}'
                                        : '📍 ${item.destination}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DataCell(
                                  Text('${item.plannedStartTime}${item.plannedEndTime != null ? " → ${item.plannedEndTime}" : ""}'),
                                ),
                                DataCell(Text(item.actualStartTime ?? '--')),
                                DataCell(Text(item.actualEndTime ?? '--')),
                                DataCell(
                                  Text(
                                    durationStr,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataCell(_buildStatusBadge(item.status)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                                        tooltip: 'Edit OD',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AssignOnDutyDialog(existingAssignment: item),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.info_outline, color: Color(0xFF414A51), size: 18),
                                        tooltip: 'View OD Details',
                                        onPressed: () => _showDetailsDialog(context, item),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMobileCard(OnDutyAssignment item) {
    final durationStr = item.durationMinutes > 0
        ? '${item.durationMinutes ~/ 60}h ${item.durationMinutes % 60}m'
        : (item.status == 'IN_PROGRESS' || item.status == 'ACTIVE' ? 'Running' : '--');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _showDetailsDialog(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF414A51),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                    tooltip: 'Edit OD',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AssignOnDutyDialog(existingAssignment: item),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildStatusBadge(item.status),
                ],
              ),
              const SizedBox(height: 10),

              // Badges: OD Type & Date
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.odType,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        item.date,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18),

              // Destination
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('📍 ', style: TextStyle(fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      item.sites.isNotEmpty
                                          ? 'Sites (${item.sites.length}): ${item.sites.map((s) => s.effectiveName).join(" → ")}'
                                          : item.destination,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
              const SizedBox(height: 10),

              // Planned Time & Duration Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Planned Time', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(
                            '${item.plannedStartTime}${item.plannedEndTime != null ? " → ${item.plannedEndTime}" : ""}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 24, width: 1, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(
                            durationStr,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (item.actualStartTime != null || item.actualEndTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.actualStartTime != null)
                      Expanded(
                        child: Text(
                          'Started: ${item.actualStartTime}',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                    if (item.actualEndTime != null)
                      Expanded(
                        child: Text(
                          'Ended: ${item.actualEndTime}',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'ASSIGNED':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Assigned';
        icon = Icons.schedule;
        break;
      case 'TRAVELING_TO_DESTINATION':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Traveling to Site';
        icon = Icons.directions_car_rounded;
        break;
      case 'REACHED_DESTINATION':
      case 'IN_PROGRESS':
      case 'ACTIVE':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        label = status.toUpperCase() == 'REACHED_DESTINATION' ? 'At Site (Working)' : 'Running';
        icon = Icons.engineering_rounded;
        break;
      case 'WORK_COMPLETED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF414A51);
        label = 'OD work completed';
        icon = Icons.task_alt;
        break;
      case 'RETURNING_TO_OFFICE':
        bg = Colors.blue.shade50;
        fg = const Color(0xFF2563EB);
        label = 'Return office from site';
        icon = Icons.directions_car_filled_rounded;
        break;
      case 'COMPLETED':
        bg = const Color(0xFF9CC70A).withValues(alpha: 0.15);
        fg = const Color(0xFF414A51);
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = status.replaceAll('_', ' ');
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, OnDutyAssignment assignment) {
    final displaySites = assignment.sites.isNotEmpty
        ? assignment.sites
        : [
            OnDutySite(
              siteId: '1',
              siteName: assignment.destinationName.isNotEmpty ? assignment.destinationName : assignment.destination,
              purpose: assignment.purpose,
              destination: assignment.destination,
              destinationAddress: assignment.destinationAddress,
              radius: assignment.destinationRadius,
              status: assignment.isCompleted ? 'COMPLETED' : assignment.status,
              reachedTime: assignment.reachedTime,
              reachedPhoto: assignment.effectiveReachedPhoto,
              workCompletedTime: assignment.workCompletedTime,
              workPhoto: assignment.effectiveWorkPhoto,
            ),
          ];

    final hasStartGps = assignment.startLatitude != null && assignment.startLongitude != null;
    final hasEndGps = assignment.endLatitude != null && assignment.endLongitude != null;

    showDialog(
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
                // Top Header Banner
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
                              assignment.employeeName,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${assignment.odType} • ${assignment.date}',
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
                      // OD SUMMARY Header
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
                                      _buildStatusBadge(assignment.status),
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
                                    assignment.durationMinutes > 0
                                        ? '${assignment.durationMinutes} min'
                                        : (assignment.actualStartTime?.isNotEmpty == true
                                            ? assignment.actualStartTime!
                                            : (assignment.plannedStartTime.isNotEmpty ? assignment.plannedStartTime : '--')),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    assignment.durationMinutes > 0 ? 'Duration' : 'Start Time',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (assignment.purpose.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Purpose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          assignment.purpose,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],

                      if (assignment.assignedBy.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Assigned By: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                            Text(assignment.assignedBy, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                          ],
                        ),
                      ],

                      if (assignment.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Notes / Instructions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(
                          assignment.notes,
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

                          return _buildMgmtTimelineSiteCard(
                            context: ctx,
                            site: site,
                            siteIndex: idx + 1,
                            isLastSite: isLast,
                            assignment: assignment,
                          );
                        },
                      ),

                      // GPS Locations if captured
                      if (hasStartGps || hasEndGps) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        const Text(
                          'GPS TRACKING LOCATIONS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        if (hasStartGps)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Location GPS', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                  Text(
                                    '${assignment.startLatitude!.toStringAsFixed(4)}, ${assignment.startLongitude!.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => _openMap(assignment.startLatitude!, assignment.startLongitude!, label: 'Start Location'),
                                icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                                label: const Text('📍 View Map', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        if (hasEndGps) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Location GPS', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                                  Text(
                                    '${assignment.endLatitude!.toStringAsFixed(4)}, ${assignment.endLongitude!.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => _openMap(assignment.endLatitude!, assignment.endLongitude!, label: 'End Location'),
                                icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                                label: const Text('📍 View Map', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],

                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // RETURN TO OFFICE Section
                      _buildMgmtReturnToOfficeSection(assignment),

                      const SizedBox(height: 20),

                      // Bottom Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AssignOnDutyDialog(existingAssignment: assignment),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                            label: const Text('Edit OD', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          ElevatedButton(
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
                        ],
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

  Widget _buildMgmtTimelineSiteCard({
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

                    if (site.reachedPhoto != null || site.workPhoto != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (site.reachedPhoto != null)
                            Expanded(
                              child: _buildMgmtPhotoThumbnail(context, 'Arrival Proof', site.reachedPhoto!),
                            ),
                          if (site.reachedPhoto != null && site.workPhoto != null)
                            const SizedBox(width: 10),
                          if (site.workPhoto != null)
                            Expanded(
                              child: _buildMgmtPhotoThumbnail(context, 'Work Proof', site.workPhoto!),
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
                  onTap: () => _openMap(startLat, startLng, label: 'Started Location - Site $siteIndex'),
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
                  onTap: () => _openMap(reachedLat, reachedLng, label: 'Reached Location - Site $siteIndex'),
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
                  onTap: () => _openMap(endLat, endLng, label: 'Completed Location - Site $siteIndex'),
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

  Widget _buildMgmtReturnToOfficeSection(OnDutyAssignment assignment) {
    final bool isCheckoutDirect = assignment.afterCompletionOption == 'CHECKOUT_FROM_OD';
    final bool hasReturned = assignment.officeReachedTime != null || assignment.actualEndTime != null || assignment.isCompleted;

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
                                : 'Returned to office${assignment.officeReachedTime != null ? " at ${assignment.officeReachedTime}" : (assignment.actualEndTime != null ? " at ${assignment.actualEndTime}" : "")}',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMgmtPhotoThumbnail(BuildContext context, String label, String photoStr) {
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
          onTap: () => _showMgmtImagePreviewDialog(context, photoStr),
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

  void _showMgmtImagePreviewDialog(BuildContext context, String photoStr) {
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
