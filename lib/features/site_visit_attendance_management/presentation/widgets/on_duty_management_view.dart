import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../on_duty/domain/on_duty_assignment.dart';
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
                                    '📍 ${item.destination}',
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
                      item.destination,
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
      case 'IN_PROGRESS':
      case 'ACTIVE':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Running';
        icon = Icons.play_circle_fill;
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
        label = status;
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
    final durationStr = assignment.durationMinutes > 0
        ? '${(assignment.durationMinutes ~/ 60).toString().padLeft(2, '0')}h ${(assignment.durationMinutes % 60).toString().padLeft(2, '0')}m'
        : '--';

    final hasStartGps = assignment.startLatitude != null && assignment.startLongitude != null;
    final hasEndGps = assignment.endLatitude != null && assignment.endLongitude != null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OD Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _detailRow('Employee', assignment.employeeName, isBold: true),
                  _detailRow('OD Type', assignment.odType),
                  _detailRow('Purpose', assignment.purpose),
                  _detailRow('Destination', '📍 ${assignment.destination}', isBold: true),
                  _detailRow('Date', assignment.date),
                  _detailRow('Planned Time', '${assignment.plannedStartTime}${assignment.plannedEndTime != null ? " → ${assignment.plannedEndTime}" : ""}'),
                  _detailRow('Actual Start Time', assignment.actualStartTime ?? '--'),
                  _detailRow('Actual End Time', assignment.actualEndTime ?? '--'),
                  _detailRow('Duration', durationStr, isBold: true),
                  _detailRow('Assigned By', assignment.assignedBy),
                  if (assignment.notes.isNotEmpty)
                    _detailRow('Notes', assignment.notes),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // GPS Start Location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Location', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            hasStartGps
                                ? '${assignment.startLatitude!.toStringAsFixed(4)}, ${assignment.startLongitude!.toStringAsFixed(4)}'
                                : 'Not Captured',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                      if (hasStartGps)
                        TextButton.icon(
                          onPressed: () => _openMap(assignment.startLatitude!, assignment.startLongitude!, label: 'Start Location'),
                          icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('📍 View Map', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // GPS End Location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Location', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            hasEndGps
                                ? '${assignment.endLatitude!.toStringAsFixed(4)}, ${assignment.endLongitude!.toStringAsFixed(4)}'
                                : 'Not Captured',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ],
                      ),
                      if (hasEndGps)
                        TextButton.icon(
                          onPressed: () => _openMap(assignment.endLatitude!, assignment.endLongitude!, label: 'End Location'),
                          icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                          label: const Text('📍 View Map', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      _buildStatusBadge(assignment.status),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9CC70A),
                          foregroundColor: const Color(0xFF414A51),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF414A51),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
