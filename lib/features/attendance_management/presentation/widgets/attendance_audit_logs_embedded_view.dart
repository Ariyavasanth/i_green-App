import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../employee/providers/employee_providers.dart';
import '../../providers/attendance_management_providers.dart';

class AttendanceAuditLogsEmbeddedView extends ConsumerStatefulWidget {
  const AttendanceAuditLogsEmbeddedView({super.key});

  @override
  ConsumerState<AttendanceAuditLogsEmbeddedView> createState() => _AttendanceAuditLogsEmbeddedViewState();
}

class _AttendanceAuditLogsEmbeddedViewState extends ConsumerState<AttendanceAuditLogsEmbeddedView> {
  int? _selectedEmployeeId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(attendanceManagementAuditProvider(_selectedEmployeeId));
    final employeesAsync = ref.watch(employeesProvider);
    final isMobile = MediaQuery.of(context).size.width < 650;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Bar
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inputWidth = isMobile ? constraints.maxWidth : 260.0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Employee Filter
                    SizedBox(
                      width: inputWidth,
                      child: employeesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Error loading employees: $e'),
                        data: (employees) => DropdownButtonFormField<int?>(
                          initialValue: _selectedEmployeeId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Filter by Employee',
                            prefixIcon: const Icon(Icons.person_search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Employees', overflow: TextOverflow.ellipsis),
                            ),
                            ...employees.map((emp) => DropdownMenuItem<int?>(
                                  value: emp.id,
                                  child: Text(
                                    '${emp.name} (${emp.department ?? 'N/A'})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedEmployeeId = val),
                        ),
                      ),
                    ),

                    // Search Filter
                    SizedBox(
                      width: inputWidth,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search audit records...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),

                    // Refresh Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF414A51),
                        side: const BorderSide(color: Color(0xFF414A51)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onPressed: () => ref.refresh(attendanceManagementAuditProvider(_selectedEmployeeId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh Logs'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Logs Data Table
        Expanded(
          child: auditLogsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading audit logs: $e', style: const TextStyle(color: Colors.red)),
            data: (logs) {
              final filtered = logs.where((log) {
                if (_searchQuery.isEmpty) return true;
                final empName = (log['employee_name'] ?? '').toString().toLowerCase();
                final dateStr = (log['date'] ?? '').toString().toLowerCase();
                final status = (log['status'] ?? '').toString().toLowerCase();
                final notes = (log['notes'] ?? '').toString().toLowerCase();
                final vStatus = (log['verification_status'] ?? '').toString().toLowerCase();
                return empName.contains(_searchQuery) ||
                    dateStr.contains(_searchQuery) ||
                    status.contains(_searchQuery) ||
                    notes.contains(_searchQuery) ||
                    vStatus.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No audit logs found matching your filters.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                        columns: const [
                          DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Check-In / Out', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Verification / Override Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Logged At', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((log) {
                          final empName = log['employee_name'] ?? 'Emp #${log['employee_id']}';
                          final dateStr = log['date'] ?? '-';
                          final status = log['status'] ?? 'Present';
                          final checkIn = log['check_in_time'] ?? log['time'] ?? '-';
                          final checkOut = log['check_out_time'] ?? '-';
                          final verificationStatus = log['verification_status'] ?? 'Manual Log';
                          final markedAt = log['marked_at'] ?? '-';
                          final notes = log['notes'] ?? '';

                          return DataRow(cells: [
                            DataCell(Text(empName.toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(dateStr.toString())),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status.toString()).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(status.toString()),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text('$checkIn - $checkOut')),
                            DataCell(Text(verificationStatus.toString())),
                            DataCell(Text(markedAt.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            DataCell(Text(notes.toString().isEmpty ? '-' : notes.toString())),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'half_day':
      case 'half-day':
        return Colors.amber.shade800;
      case 'absent':
        return Colors.red;
      case 'on duty':
      case 'on_duty':
        return const Color(0xFF9CC70A);
      default:
        return const Color(0xFF414A51);
    }
  }
}
