import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../on_duty/domain/on_duty_assignment.dart';
import '../../../on_duty/providers/on_duty_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final assignmentsAsync = ref.watch(
      allOnDutyAssignmentsProvider((date: null, statusFilter: null, employeeId: null)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Controls
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ON-DUTY MANAGEMENT',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF414A51),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track active, assigned, and completed employee tasks',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(allOnDutyAssignmentsProvider);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Employee...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),

                  // Status Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Status: All')),
                          DropdownMenuItem(value: 'assigned', child: Text('🟡 Assigned')),
                          DropdownMenuItem(value: 'active', child: Text('🔵 Active')),
                          DropdownMenuItem(value: 'completed', child: Text('🟢 Completed')),
                          DropdownMenuItem(value: 'requires_review', child: Text('🔴 Requires Review')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                  ),

                  // Date Picker Button
                  OutlinedButton.icon(
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
                      style: const TextStyle(color: Color(0xFF414A51)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assignments Table / Cards
          assignmentsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
              ),
            ),
            error: (e, _) => Center(child: Text('Error loading assignments: $e')),
            data: (allAssignments) {
              final filtered = allAssignments.where((item) {
                final matchSearch = _searchQuery.isEmpty ||
                    item.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    item.task.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    item.destination.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchStatus = _selectedStatus == 'All' || item.status == _selectedStatus;
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
                    padding: const EdgeInsets.all(40.0),
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
                          'Use "+ Assign On-Duty" in the Site Visit Attendance tab to assign work.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
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
                        DataColumn(label: Text('From')),
                        DataColumn(label: Text('Destination')),
                        DataColumn(label: Text('Task')),
                        DataColumn(label: Text('Started')),
                        DataColumn(label: Text('Ended')),
                        DataColumn(label: Text('Duration')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((item) {
                        final durationStr = item.durationMinutes > 0
                            ? '${item.durationMinutes ~/ 60}h ${item.durationMinutes % 60}m'
                            : (item.status == 'active' ? 'Active' : '--');

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                item.employeeName,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  const Text('📍 ', style: TextStyle(fontSize: 14)),
                                  Text(item.fromLocation),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  const Text('📍 ', style: TextStyle(fontSize: 14)),
                                  Text(item.destination, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 160,
                                child: Text(
                                  item.task,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            DataCell(Text(item.startedTime ?? '--')),
                            DataCell(Text(item.completedTime ?? '--')),
                            DataCell(
                              Text(
                                durationStr,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(_buildStatusBadge(item.status)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: Color(0xFF414A51)),
                                tooltip: 'View Details',
                                onPressed: () => _showDetailsDialog(context, item),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'assigned':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = '🟡 Assigned';
        icon = Icons.schedule;
        break;
      case 'active':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = '🔵 Active';
        icon = Icons.play_circle_fill;
        break;
      case 'completed':
        bg = const Color(0xFF9CC70A).withValues(alpha: 0.15);
        fg = const Color(0xFF414A51);
        label = '🟢 Completed';
        icon = Icons.check_circle;
        break;
      case 'requires_review':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = '🔴 Requires Review';
        icon = Icons.warning_amber_rounded;
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

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'On-Duty Details',
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
                _detailRow('Original Site', '📍 ${assignment.fromLocation}'),
                _detailRow('Destination', '📍 ${assignment.destination}', isBold: true),
                _detailRow('Task', assignment.task),
                if (assignment.instructions.isNotEmpty)
                  _detailRow('Instructions', assignment.instructions),
                _detailRow('Assigned By', assignment.assignedBy),
                _detailRow('Assigned Time', assignment.assignedTime),
                _detailRow('Started', assignment.startedTime ?? '--'),
                _detailRow('Completed', assignment.completedTime ?? '--'),
                _detailRow('On-Duty Duration', durationStr, isBold: true),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    _buildStatusBadge(assignment.status),
                  ],
                ),
                const SizedBox(height: 8),
                _detailRow(
                  'Checkout from destination',
                  assignment.allowCheckoutFromDestination ? 'Allowed' : 'Not Allowed',
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9CC70A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
