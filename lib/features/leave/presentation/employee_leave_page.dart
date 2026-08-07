import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../employee/domain/employee.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_request.dart';
import '../providers/leave_providers.dart';

enum EmployeeLeaveTab {
  dashboard,
  requests,
  calendar,
  history,
  salary,
}

class EmployeeLeavePage extends ConsumerStatefulWidget {
  const EmployeeLeavePage({super.key});

  @override
  ConsumerState<EmployeeLeavePage> createState() => _EmployeeLeavePageState();
}

class _EmployeeLeavePageState extends ConsumerState<EmployeeLeavePage> {
  EmployeeLeaveTab _activeTab = EmployeeLeaveTab.dashboard;

  // Calendar State
  DateTime _focusedMonth = DateTime.now();

  // History & Filter State
  String _historyLeaveType = 'All';
  String _historyStatus = 'All';

  // Apply Form State
  String _selectedLeaveType = 'Sick Leave';
  DateTime? _fromDate = DateTime.now();
  DateTime? _toDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();

  // Quick Search
  final TextEditingController _globalSearchController = TextEditingController();
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Leave Approved',
      'message': 'Your Sick Leave for 12-Aug-2026 has been approved.',
      'time': '10 mins ago',
      'icon': Icons.check_circle_outline,
      'color': const Color(0xFF2E7D32),
      'isRead': false,
    },
    {
      'id': 2,
      'title': 'Manager Comment',
      'message': 'Please handover pending tasks before starting leave.',
      'time': '2 hours ago',
      'icon': Icons.comment_outlined,
      'color': const Color(0xFF414A51),
      'isRead': false,
    },
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFE65100);
      case 'denied':
      case 'rejected':
        return const Color(0xFFC62828);
      case 'cancelled':
        return const Color(0xFF414A51);
      default:
        return const Color(0xFF414A51);
    }
  }

  String _formatDateStr(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        return DateFormat('dd MMM yyyy').format(d);
      }
    } catch (_) {}
    return dateStr;
  }

  Future<void> _cancelRequest(LeaveRequest req, Employee currentEmp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel this pending leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, keep it', style: TextStyle(color: Color(0xFF414A51))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(leaveRepositoryProvider).cancelLeaveRequest(req.id, currentEmp.fullName);
        ref.invalidate(leaveRequestsProvider(currentEmp.id));
        ref.invalidate(allLeaveRequestsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request cancelled successfully'),
              backgroundColor: Color(0xFF414A51),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling request: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    }
  }

  void _showApplyLeaveDialog(Employee currentEmp) {
    _selectedLeaveType = 'Sick Leave';
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _reasonController.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double days = 1.0;
            if (_fromDate != null && _toDate != null) {
              final diff = _toDate!.difference(_fromDate!).inDays + 1;
              days = math.max(1.0, diff.toDouble());
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Apply For Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF414A51))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leave Type Dropdown
                      const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLeaveType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                          ),
                        ),
                        items: [
                          'Sick Leave',
                          'Casual Leave',
                          'Annual Leave',
                          'Optional Leave',
                          'Work From Home',
                          'Comp Off',
                        ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedLeaveType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // From Date and To Date
                      Row(
                        children: [
                          // From Date Box
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _fromDate ?? DateTime.now(),
                                      firstDate: DateTime(2025),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _fromDate = picked;
                                        // Default same day in both boxes for 1 day leave
                                        _toDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _fromDate != null ? DateFormat('dd MMM yyyy').format(_fromDate!) : 'Select',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // To Date Box
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                                      firstDate: _fromDate ?? DateTime(2025),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _toDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _toDate != null ? DateFormat('dd MMM yyyy').format(_toDate!) : 'Select',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF414A51)),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total Duration: ${days.toStringAsFixed(1)} Day(s)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9CC70A)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter reason / description...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: const Color(0xFF414A51),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    if (_reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a description / reason'),
                          backgroundColor: Color(0xFFC62828),
                        ),
                      );
                      return;
                    }

                    final fromStr = DateFormat('dd-MM-yyyy').format(_fromDate!);
                    final toStr = DateFormat('dd-MM-yyyy').format(_toDate!);

                    final newReq = LeaveRequest(
                      id: 0,
                      employeeId: currentEmp.id,
                      employeeName: currentEmp.fullName,
                      employeeCustomId: currentEmp.employeeId,
                      leaveType: _selectedLeaveType,
                      fromDate: fromStr,
                      toDate: toStr,
                      numDays: days,
                      reason: _reasonController.text.trim(),
                      status: 'Pending',
                      createdAt: DateTime.now().toIso8601String(),
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(dialogCtx);

                    try {
                      await ref.read(leaveRepositoryProvider).submitLeaveRequest(newReq);
                      ref.invalidate(leaveRequestsProvider(currentEmp.id));
                      ref.invalidate(allLeaveRequestsProvider);

                      nav.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Leave request submitted successfully!'),
                          backgroundColor: Color(0xFF2E7D32),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to submit: $e'),
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);

    if (currentEmp == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
        ),
      );
    }

    final requestsAsync = ref.watch(leaveRequestsProvider(currentEmp.id));
    final balancesAsync = ref.watch(leaveBalancesProvider(currentEmp.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            children: [
              // Header Bar
              _buildHeader(currentEmp, isMobile),

              // Desktop/Tablet Sub-Navigation Tabs
              if (!isMobile) _buildDesktopTabs(),

              // Main Active Section View
              Expanded(
                child: requestsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                  ),
                  error: (err, stack) => Center(
                    child: SelectableText('Error loading requests: $err'),
                  ),
                  data: (requests) {
                    return balancesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF9CC70A)),
                      ),
                      error: (err, stack) => Center(
                        child: SelectableText('Error loading balances: $err'),
                      ),
                      data: (balances) {
                        return _buildActiveTabContent(
                          currentEmp,
                          requests,
                          balances,
                          isMobile,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: const Color(0xFF414A51),
        onPressed: () => _showApplyLeaveDialog(currentEmp),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 768
          ? _buildMobileBottomNav()
          : null,
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(Employee currentEmp, bool isMobile) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    final unreadCount = _notifications.where((n) => !n['isRead']).length;
    final empName = currentEmp.fullName.isNotEmpty ? currentEmp.fullName : 'Employee';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.2),
              child: Text(
                empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                style: const TextStyle(
                  color: Color(0xFF414A51),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Greeting + Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    empName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF414A51),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            if (!isMobile) ...[
              // Search input
              SizedBox(
                width: 220,
                height: 38,
                child: TextField(
                  controller: _globalSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search leaves...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Notification Bell Button
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF414A51)),
                  onPressed: () {
                    _showNotificationBottomSheet(context);
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC62828),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- DESKTOP TABS ---
  Widget _buildDesktopTabs() {
    final desktopTabs = [
      EmployeeLeaveTab.dashboard,
      EmployeeLeaveTab.requests,
      EmployeeLeaveTab.calendar,
      EmployeeLeaveTab.history,
      EmployeeLeaveTab.salary,
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: desktopTabs.map((tab) {
            final isActive = _activeTab == tab;
            return InkWell(
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? const Color(0xFF9CC70A) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTabIcon(tab),
                      size: 18,
                      color: isActive ? const Color(0xFF414A51) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTabTitle(tab),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? const Color(0xFF414A51) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- MOBILE BOTTOM NAVIGATION ---
  Widget _buildMobileBottomNav() {
    final mobileTabs = [
      EmployeeLeaveTab.dashboard,
      EmployeeLeaveTab.requests,
      EmployeeLeaveTab.calendar,
    ];

    return BottomNavigationBar(
      currentIndex: mobileTabs.contains(_activeTab)
          ? mobileTabs.indexOf(_activeTab)
          : 0,
      onTap: (index) {
        setState(() => _activeTab = mobileTabs[index]);
      },
      selectedItemColor: const Color(0xFF414A51),
      unselectedItemColor: const Color(0xFF94A3B8),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: mobileTabs.map((t) {
        return BottomNavigationBarItem(
          icon: Icon(_getTabIcon(t)),
          label: _getTabTitle(t),
        );
      }).toList(),
    );
  }

  IconData _getTabIcon(EmployeeLeaveTab tab) {
    switch (tab) {
      case EmployeeLeaveTab.dashboard:
        return Icons.dashboard_outlined;
      case EmployeeLeaveTab.requests:
        return Icons.format_list_bulleted_outlined;
      case EmployeeLeaveTab.calendar:
        return Icons.calendar_month_outlined;
      case EmployeeLeaveTab.history:
        return Icons.history_outlined;
      case EmployeeLeaveTab.salary:
        return Icons.payments_outlined;
    }
  }

  String _getTabTitle(EmployeeLeaveTab tab) {
    switch (tab) {
      case EmployeeLeaveTab.dashboard:
        return 'Dashboard';
      case EmployeeLeaveTab.requests:
        return 'My Requests';
      case EmployeeLeaveTab.calendar:
        return 'Calendar';
      case EmployeeLeaveTab.history:
        return 'Leave History';
      case EmployeeLeaveTab.salary:
        return 'Salary & LOP';
    }
  }

  // --- ACTIVE TAB ROUTER ---
  Widget _buildActiveTabContent(
    Employee currentEmp,
    List<LeaveRequest> requests,
    List<LeaveBalance> balances,
    bool isMobile,
  ) {
    switch (_activeTab) {
      case EmployeeLeaveTab.dashboard:
        return _buildDashboardSection(currentEmp, requests, balances, isMobile);
      case EmployeeLeaveTab.requests:
        return _buildMyRequestsSection(currentEmp, requests, isMobile);
      case EmployeeLeaveTab.calendar:
        return _buildCalendarSection(requests, isMobile);
      case EmployeeLeaveTab.history:
        return _buildHistorySection(requests, isMobile);
      case EmployeeLeaveTab.salary:
        return _buildSalaryLopSection(currentEmp, isMobile);
    }
  }

  // ==========================================
  // 1. DASHBOARD SECTION
  // ==========================================
  Widget _buildDashboardSection(
    Employee currentEmp,
    List<LeaveRequest> requests,
    List<LeaveBalance> balances,
    bool isMobile,
  ) {
    final pendingCount = requests.where((r) => r.status == 'Pending').length;
    final approvedCount = requests.where((r) => r.status == 'Approved').length;
    final totalRequests = requests.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Summary Cards Grid
          LayoutBuilder(builder: (context, box) {
            final cols = isMobile ? 2 : 3;
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: isMobile ? 1.4 : 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSummaryCard(
                  'Total Requests',
                  '$totalRequests',
                  Icons.folder_outlined,
                  const Color(0xFF0288D1),
                  const Color(0xFFE1F5FE),
                ),
                _buildSummaryCard(
                  'Pending Requests',
                  '$pendingCount',
                  Icons.hourglass_top_outlined,
                  const Color(0xFFE65100),
                  const Color(0xFFFFF3E0),
                ),
                _buildSummaryCard(
                  'Approved Leaves',
                  '$approvedCount',
                  Icons.check_circle_outline,
                  const Color(0xFF2E7D32),
                  const Color(0xFFE8F5E9),
                ),
              ],
            );
          }),

          const SizedBox(height: 20),

          // Primary Quick Action Button: + Apply Leave
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: const Color(0xFF414A51),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _showApplyLeaveDialog(currentEmp),
              icon: const Icon(Icons.add_circle, size: 22),
              label: const Text(
                '+ Apply Leave',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activity / Requests List
          const Text(
            'Recent Leave Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No recent leave requests found.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          else
            Column(
              children: requests.take(5).map((req) => _buildRequestCard(req, currentEmp, isMobile)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color iconColor, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. MY REQUESTS SECTION
  // ==========================================
  Widget _buildMyRequestsSection(Employee currentEmp, List<LeaveRequest> requests, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Leave Requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CC70A),
                  foregroundColor: const Color(0xFF414A51),
                ),
                onPressed: () => _showApplyLeaveDialog(currentEmp),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Apply New'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (requests.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No leave requests submitted yet.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (ctx, idx) => _buildRequestCard(requests[idx], currentEmp, isMobile),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest req, Employee currentEmp, bool isMobile) {
    final statusColor = _getStatusColor(req.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_note, size: 18, color: Color(0xFF414A51)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.leaveType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF414A51))),
                      Text('Submitted: ${_formatDateStr(req.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  req.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDateStr(req.fromDate)} → ${_formatDateStr(req.toDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF414A51)),
              ),
              Text(
                '${req.numDays.toStringAsFixed(1)} Day(s)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9CC70A)),
              ),
            ],
          ),
          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${req.reason}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Rejection Reason: ${req.rejectionReason}',
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
              ),
            ),
          ],
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _showRequestDetailsModal(req),
                child: const Text('View Details', style: TextStyle(color: Color(0xFF414A51), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (req.status.toLowerCase() == 'pending')
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFEF5350)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  onPressed: () => _cancelRequest(req, currentEmp),
                  child: const Text('Cancel Request', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CALENDAR SECTION
  // ==========================================
  Widget _buildCalendarSection(List<LeaveRequest> requests, bool isMobile) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildLegendDot('Approved', const Color(0xFF2E7D32)),
              const SizedBox(width: 12),
              _buildLegendDot('Pending', const Color(0xFFE65100)),
              const SizedBox(width: 12),
              _buildLegendDot('Rejected', const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 16),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: firstDayOfMonth.weekday % 7 + daysInMonth,
                  itemBuilder: (ctx, idx) {
                    final offset = firstDayOfMonth.weekday % 7;
                    if (idx < offset) return const SizedBox();

                    final dayNum = idx - offset + 1;
                    final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);

                    LeaveRequest? matchingReq;
                    for (final r in requests) {
                      final from = _parseDateStr(r.fromDate);
                      final to = _parseDateStr(r.toDate);
                      if (from != null && to != null) {
                        if (!cellDate.isBefore(from) && !cellDate.isAfter(to)) {
                          matchingReq = r;
                          break;
                        }
                      }
                    }

                    Color? indicatorColor;
                    if (matchingReq != null) {
                      indicatorColor = _getStatusColor(matchingReq.status);
                    }

                    return InkWell(
                      onTap: () {
                        if (matchingReq != null) {
                          _showCalendarDateDetailsSheet(cellDate, matchingReq);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: indicatorColor != null ? indicatorColor.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: indicatorColor ?? Colors.transparent,
                            width: indicatorColor != null ? 1.5 : 0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: Color(0xFF414A51) == Colors.transparent ? MainAxisAlignment.center : MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontWeight: indicatorColor != null ? FontWeight.bold : FontWeight.normal,
                                color: indicatorColor ?? const Color(0xFF414A51),
                              ),
                            ),
                            if (indicatorColor != null)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  DateTime? _parseDateStr(String s) {
    try {
      final p = s.split('-');
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return null;
  }

  // ==========================================
  // 4. LEAVE HISTORY SECTION
  // ==========================================
  Widget _buildHistorySection(List<LeaveRequest> requests, bool isMobile) {
    final filtered = requests.where((r) {
      if (_historyStatus != 'All' && r.status.toLowerCase() != _historyStatus.toLowerCase()) {
        return false;
      }
      if (_historyLeaveType != 'All' && r.leaveType.toLowerCase() != _historyLeaveType.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leave History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
          const SizedBox(height: 12),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: _historyStatus,
                  items: ['All', 'Approved', 'Pending', 'Denied', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text('Status: $s'))).toList(),
                  onChanged: (v) => setState(() => _historyStatus = v!),
                ),
                DropdownButton<String>(
                  value: _historyLeaveType,
                  items: ['All', 'Casual Leave', 'Sick Leave', 'Annual Leave', 'Optional Leave'].map((s) => DropdownMenuItem(value: s, child: Text('Type: $s'))).toList(),
                  onChanged: (v) => setState(() => _historyLeaveType = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Center(child: Text('No historical leave records match the filters.', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final r = filtered[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(r.leaveType, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r.fromDate} → ${r.toDate} (${r.numDays} days)\nReason: ${r.reason}'),
                    trailing: Text(r.status, style: TextStyle(color: _getStatusColor(r.status), fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. SALARY & LOSS OF PAY (LOP) SECTION
  // ==========================================
  Widget _buildSalaryLopSection(Employee currentEmp, bool isMobile) {
    final now = DateTime.now();
    final calcAsync = ref.watch(salaryCalculationProvider(
      SalaryCalcParam(employeeId: currentEmp.id, year: now.year, month: now.month, workingDays: 26),
    ));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: calcAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
        error: (err, stack) => Center(child: Text('Error calculating salary: $err')),
        data: (calc) {
          final hasLop = calc.totalLopDays > 0;
          final highlightColor = hasLop ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Salary & Loss of Pay Calculation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
              const SizedBox(height: 16),

              // Highlight Card: Final Payable Salary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: highlightColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Final Payable Salary (Current Month)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${calc.finalPayableSalary.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    if (hasLop)
                      Text('Includes LOP Deduction of ₹${calc.lopDeductionAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12))
                    else
                      const Text('No LOP Deductions applied this month 🎉', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Two Sections: Salary vs Leave Impact
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salary Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(height: 16),
                          _buildSalaryRow('Gross Monthly Salary', '₹${calc.grossMonthlySalary.toStringAsFixed(0)}'),
                          _buildSalaryRow('Working Days', '${calc.totalWorkingDays} Days'),
                          _buildSalaryRow('Per Day Salary Rate', '₹${calc.perDaySalary.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Leave Impact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(height: 16),
                          _buildSalaryRow('Approved Leave Days', '${calc.totalApprovedLeaveDays} Days'),
                          _buildSalaryRow('LOP Days', '${calc.totalLopDays} Days'),
                          _buildSalaryRow('LOP Deduction', '₹${calc.lopDeductionAmount.toStringAsFixed(0)}', isRed: hasLop),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSalaryRow(String label, String val, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isRed ? const Color(0xFFC62828) : const Color(0xFF414A51))),
        ],
      ),
    );
  }

  // --- MODALS & DIALOGS ---
  void _showNotificationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._notifications.map((n) => ListTile(
                  leading: Icon(n['icon'] as IconData, color: n['color'] as Color),
                  title: Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(n['message'] as String, style: const TextStyle(fontSize: 12)),
                  trailing: Text(n['time'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                )),
          ],
        ),
      ),
    );
  }

  void _showRequestDetailsModal(LeaveRequest req) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave Details - ${req.leaveType}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text('Dates: ${req.fromDate} to ${req.toDate} (${req.numDays} days)'),
            const SizedBox(height: 6),
            Text('Status: ${req.status}'),
            const SizedBox(height: 6),
            Text('Reason: ${req.reason}'),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCalendarDateDetailsSheet(DateTime date, LeaveRequest req) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave Info: ${DateFormat('dd MMM yyyy').format(date)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Text('Leave Type: ${req.leaveType}'),
            const SizedBox(height: 6),
            Text('Status: ${req.status}'),
            const SizedBox(height: 6),
            Text('Duration: ${req.numDays} Day(s)'),
            const SizedBox(height: 6),
            Text('Reason: ${req.reason}'),
          ],
        ),
      ),
    );
  }
}
