import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../employee/domain/employee.dart';
import '../domain/leave_request.dart';
import '../providers/leave_providers.dart';

class MyLeaveRequestsPage extends ConsumerStatefulWidget {
  final Employee currentEmp;

  const MyLeaveRequestsPage({super.key, required this.currentEmp});

  @override
  ConsumerState<MyLeaveRequestsPage> createState() => _MyLeaveRequestsPageState();
}

class _MyLeaveRequestsPageState extends ConsumerState<MyLeaveRequestsPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _monthStatus = 'All';

  DateTime? _parseKey(String value) {
    if (value.isEmpty) return null;
    try {
      final isoDate = DateTime.tryParse(value);
      if (isoDate != null) return isoDate;

      final parts = value.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isInMonth(LeaveRequest req, DateTime month) {
    final from = _parseKey(req.fromDate);
    final to = _parseKey(req.toDate) ?? from;
    if (from == null && to == null) return false;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    if (from != null && from.isAfter(start.subtract(const Duration(seconds: 1))) && from.isBefore(end.add(const Duration(seconds: 1)))) {
      return true;
    }
    if (to != null && to.isAfter(start.subtract(const Duration(seconds: 1))) && to.isBefore(end.add(const Duration(seconds: 1)))) {
      return true;
    }
    return false;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'present':
        return const Color(0xFF2E7D32);
      case 'pending':
      case 'late':
        return const Color(0xFFE65100);
      case 'denied':
      case 'rejected':
      case 'absent':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF414A51);
    }
  }

  String _formatDateStr(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final isoDate = DateTime.tryParse(dateStr);
      if (isoDate != null) {
        return DateFormat('dd MMM yyyy').format(isoDate);
      }
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          return DateFormat('dd MMM yyyy').format(d);
        } else {
          final d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          return DateFormat('dd MMM yyyy').format(d);
        }
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatDurationDisplay(LeaveRequest req) {
    if (req.leaveType.toLowerCase().startsWith('permission')) {
      if (req.leaveType.contains('(') && req.leaveType.contains(')')) {
        final timePart = req.leaveType.substring(req.leaveType.indexOf('(') + 1, req.leaveType.indexOf(')'));
        return 'Permission ($timePart)';
      }
      final hours = req.numDays * 8.0;
      if (hours > 0) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        if (h > 0 && m > 0) return '$h Hr $m Mins';
        if (h > 0) return '$h Hour${h > 1 ? 's' : ''}';
        return '$m Mins';
      }
      return 'Permission';
    }
    final isWhole = (req.numDays == req.numDays.roundToDouble());
    final daysStr = isWhole ? req.numDays.toInt().toString() : req.numDays.toStringAsFixed(1);
    return '$daysStr Day${req.numDays == 1.0 ? '' : 's'}';
  }

  void _showViewLeaveDialog(LeaveRequest req) {
    final statusColor = _getStatusColor(req.status);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  req.leaveType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Submitted On', _formatDateStr(req.createdAt)),
                  const SizedBox(height: 12),
                  _detailRow('Date Range', '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}'),
                  const SizedBox(height: 12),
                  _detailRow('Duration', _formatDurationDisplay(req)),
                  const SizedBox(height: 12),
                  _detailRow('Reason', req.reason.isNotEmpty ? req.reason : 'N/A'),
                  if (req.approvedBy != null && req.approvedBy!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Approved By', req.approvedBy!),
                  ],
                  if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Rejection Reason', req.rejectionReason!),
                  ],
                  if (req.overrideReason != null && req.overrideReason!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow('Override Note', req.overrideReason!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveRequestsAsync = ref.watch(leaveRequestsProvider(widget.currentEmp.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Requests',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
        ),
        centerTitle: false,
      ),
      body: leaveRequestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allRequests) {
          final monthRequests = allRequests.where((r) => _isInMonth(r, _selectedMonth)).toList();

          final totalInMonth = monthRequests.length;
          final pendingInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'pending').length;
          final approvedInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'approved').length;
          final deniedInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'denied' || r.status.toLowerCase() == 'rejected').length;
          final cancelledInMonth = monthRequests.where((r) => r.status.toLowerCase() == 'cancelled').length;

          final filteredMonthRequests = monthRequests.where((r) {
            if (_monthStatus != 'All' && r.status.toLowerCase() != _monthStatus.toLowerCase()) {
              return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Month Navigation Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Color(0xFF414A51)),
                            onPressed: () {
                              setState(() {
                                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                              });
                            },
                          ),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedMonth,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedMonth = DateTime(picked.year, picked.month, 1);
                                });
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, size: 18, color: Color(0xFF9CC70A)),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMMM yyyy').format(_selectedMonth),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Color(0xFF414A51)),
                            onPressed: () {
                              setState(() {
                                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Summary Stats Cards
                    Row(
                      children: [
                        _buildStatTile('Total', '$totalInMonth', const Color(0xFF0288D1)),
                        const SizedBox(width: 8),
                        _buildStatTile('Pending', '$pendingInMonth', const Color(0xFFE65100)),
                        const SizedBox(width: 8),
                        _buildStatTile('Approved', '$approvedInMonth', const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        _buildStatTile('Denied', '${deniedInMonth + cancelledInMonth}', const Color(0xFFC62828)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Status Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _statusChip('All ($totalInMonth)', 'All'),
                          const SizedBox(width: 6),
                          _statusChip('Pending ($pendingInMonth)', 'Pending'),
                          const SizedBox(width: 6),
                          _statusChip('Approved ($approvedInMonth)', 'Approved'),
                          const SizedBox(width: 6),
                          _statusChip('Denied ($deniedInMonth)', 'Denied'),
                          const SizedBox(width: 6),
                          _statusChip('Cancelled ($cancelledInMonth)', 'Cancelled'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Request Cards List
              Expanded(
                child: filteredMonthRequests.isEmpty
                    ? Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No requests found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredMonthRequests.length,
                        itemBuilder: (context, index) {
                          final req = filteredMonthRequests[index];
                          return _buildRequestCard(req);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatTile(String label, String count, Color countColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: countColor)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = _monthStatus.toLowerCase() == value.toLowerCase();
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF9CC70A).withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF414A51) : const Color(0xFF64748B),
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() => _monthStatus = value);
      },
    );
  }

  Widget _buildRequestCard(LeaveRequest req) {
    final statusColor = _getStatusColor(req.status);
    final isPermission = req.leaveType.toLowerCase().startsWith('permission');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPermission
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                      : const Color(0xFF9CC70A).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPermission ? Icons.access_time : Icons.event_note,
                  size: 18,
                  color: isPermission ? const Color(0xFF2563EB) : const Color(0xFF414A51),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.leaveType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submitted: ${_formatDateStr(req.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      req.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'View Details',
                    onPressed: () => _showViewLeaveDialog(req),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDurationDisplay(req),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPermission ? const Color(0xFF2563EB) : const Color(0xFF9CC70A),
                ),
              ),
            ],
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${req.reason}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
