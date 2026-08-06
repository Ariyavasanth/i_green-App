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
  balance,
  apply,
  requests,
  calendar,
  history,
  salary,
  policy,
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

  // Apply Form State (Multi-step)
  int _applyStep = 1;
  String _selectedLeaveType = 'Casual Leave';
  DateTime? _fromDate = DateTime.now();
  DateTime? _toDate = DateTime.now();
  bool _isHalfDay = false;
  String _halfDayPeriod = 'First Half';
  final TextEditingController _reasonController = TextEditingController();
  bool _isEmergency = false;
  String? _attachedFileName;

  // Quick Search
  final TextEditingController _globalSearchController = TextEditingController();
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Leave Approved',
      'message': 'Your Casual Leave for 12-Aug-2026 has been approved by HR.',
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
    {
      'id': 3,
      'title': 'Leave Balance Updated',
      'message': 'Monthly allocation of 1.0 day added to Casual Leave.',
      'time': '1 day ago',
      'icon': Icons.account_balance_wallet_outlined,
      'color': const Color(0xFF9CC70A),
      'isRead': true,
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
        return const Color(0xFF2E7D32); // 🟢 Approved Green
      case 'pending':
        return const Color(0xFFE65100); // 🟡 Pending Amber/Orange
      case 'denied':
      case 'rejected':
        return const Color(0xFFC62828); // 🔴 Rejected Red
      case 'cancelled':
        return const Color(0xFF414A51); // 🔵 Cancelled Charcoal/Blue
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

  double _calculateNumDays() {
    if (_fromDate == null || _toDate == null) return 0;
    if (_isHalfDay) return 0.5;
    final diff = _toDate!.difference(_fromDate!).inDays + 1;
    return math.max(1.0, diff.toDouble());
  }

  // Submit leave request to Firestore via Provider
  Future<void> _submitRequest(Employee currentEmp, double currentAvailableBalance) async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid reason for leave'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    final days = _calculateNumDays();
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
      isEmergency: _isEmergency,
      attachmentUrl: _attachedFileName,
      isHalfDay: _isHalfDay,
      halfDayPeriod: _isHalfDay ? _halfDayPeriod : null,
    );

    try {
      await ref.read(leaveRepositoryProvider).submitLeaveRequest(newReq);
      ref.invalidate(leaveRequestsProvider(currentEmp.id));
      ref.invalidate(allLeaveRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        setState(() {
          _applyStep = 1;
          _reasonController.clear();
          _attachedFileName = null;
          _activeTab = EmployeeLeaveTab.requests;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
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

    if (confirmed == true) {
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: EmployeeLeaveTab.values.map((tab) {
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
      EmployeeLeaveTab.apply,
      EmployeeLeaveTab.requests,
      EmployeeLeaveTab.calendar,
      EmployeeLeaveTab.policy,
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
      case EmployeeLeaveTab.balance:
        return Icons.account_balance_wallet_outlined;
      case EmployeeLeaveTab.apply:
        return Icons.add_circle_outline;
      case EmployeeLeaveTab.requests:
        return Icons.format_list_bulleted_outlined;
      case EmployeeLeaveTab.calendar:
        return Icons.calendar_month_outlined;
      case EmployeeLeaveTab.history:
        return Icons.history_outlined;
      case EmployeeLeaveTab.salary:
        return Icons.payments_outlined;
      case EmployeeLeaveTab.policy:
        return Icons.article_outlined;
    }
  }

  String _getTabTitle(EmployeeLeaveTab tab) {
    switch (tab) {
      case EmployeeLeaveTab.dashboard:
        return 'Dashboard';
      case EmployeeLeaveTab.balance:
        return 'My Balance';
      case EmployeeLeaveTab.apply:
        return 'Apply Leave';
      case EmployeeLeaveTab.requests:
        return 'My Requests';
      case EmployeeLeaveTab.calendar:
        return 'Calendar';
      case EmployeeLeaveTab.history:
        return 'Leave History';
      case EmployeeLeaveTab.salary:
        return 'Salary & LOP';
      case EmployeeLeaveTab.policy:
        return 'Policy';
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
      case EmployeeLeaveTab.balance:
        return _buildBalanceSection(balances, isMobile);
      case EmployeeLeaveTab.apply:
        return _buildApplyLeaveSection(currentEmp, balances, isMobile);
      case EmployeeLeaveTab.requests:
        return _buildMyRequestsSection(currentEmp, requests, isMobile);
      case EmployeeLeaveTab.calendar:
        return _buildCalendarSection(requests, isMobile);
      case EmployeeLeaveTab.history:
        return _buildHistorySection(requests, isMobile);
      case EmployeeLeaveTab.salary:
        return _buildSalaryLopSection(currentEmp, isMobile);
      case EmployeeLeaveTab.policy:
        return _buildPolicySection(isMobile);
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
    double totalAvailable = 0;
    for (final b in balances) {
      totalAvailable += b.availableLeaves;
    }
    if (balances.isEmpty) totalAvailable = 12.0;

    final pendingCount = requests.where((r) => r.status == 'Pending').length;
    final approvedCount = requests.where((r) => r.status == 'Approved').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Summary Cards Grid
          LayoutBuilder(builder: (context, box) {
            final cols = isMobile ? 2 : 4;
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: isMobile ? 1.4 : 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSummaryCard(
                  'Leave Balance',
                  '${totalAvailable.toStringAsFixed(1)} Days',
                  Icons.account_balance_wallet_outlined,
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
                _buildSummaryCard(
                  'Remaining Leave',
                  '${totalAvailable.toStringAsFixed(1)} Days',
                  Icons.event_available_outlined,
                  const Color(0xFF9CC70A),
                  const Color(0xFFF7FCE8),
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
              onPressed: () {
                setState(() => _activeTab = EmployeeLeaveTab.apply);
              },
              icon: const Icon(Icons.add_circle, size: 22),
              label: const Text(
                '+ Apply Leave',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Action Secondary Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = EmployeeLeaveTab.policy),
                  icon: const Icon(Icons.policy_outlined, size: 16, color: Color(0xFF414A51)),
                  label: const Text('Leave Policy', style: TextStyle(color: Color(0xFF414A51), fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeTab = EmployeeLeaveTab.policy),
                  icon: const Icon(Icons.celebration_outlined, size: 16, color: Color(0xFF414A51)),
                  label: const Text('Holidays', style: TextStyle(color: Color(0xFF414A51), fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showContactHrDialog(),
                  icon: const Icon(Icons.support_agent_outlined, size: 16, color: Color(0xFF414A51)),
                  label: const Text('Contact HR', style: TextStyle(color: Color(0xFF414A51), fontSize: 13)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Leave Balance Cards Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave Balances',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
              ),
              TextButton(
                onPressed: () => setState(() => _activeTab = EmployeeLeaveTab.balance),
                child: const Text('View All', style: TextStyle(color: Color(0xFF9CC70A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDashboardBalanceGrid(balances, isMobile),

          const SizedBox(height: 24),

          // Recent Activity / Upcoming Leaves
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
              children: requests.take(3).map((req) => _buildRequestCard(req, currentEmp, isMobile)).toList(),
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

  Widget _buildDashboardBalanceGrid(List<LeaveBalance> balances, bool isMobile) {
    final displayTypes = [
      {'name': 'Casual Leave', 'allocated': 12.0, 'icon': Icons.beach_access},
      {'name': 'Sick Leave', 'allocated': 10.0, 'icon': Icons.medical_services_outlined},
      {'name': 'Optional Leave', 'allocated': 3.0, 'icon': Icons.star_border},
      {'name': 'Work From Home', 'allocated': 24.0, 'icon': Icons.home_work_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: displayTypes.length,
      itemBuilder: (context, index) {
        final dt = displayTypes[index];
        final match = balances.firstWhere(
          (b) => b.leaveType.toLowerCase() == dt['name'].toString().toLowerCase(),
          orElse: () => LeaveBalance(
            id: 0,
            employeeId: 0,
            leaveType: dt['name'].toString(),
            allowedLeaves: (dt['allocated'] as num).toDouble(),
            usedLeaves: 2.0,
            availableLeaves: (dt['allocated'] as num).toDouble() - 2.0,
            effectiveDate: '',
            allocationFrequency: 'Monthly',
          ),
        );

        final percent = (match.usedLeaves / math.max(1.0, match.allowedLeaves)).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      match.leaveType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF414A51)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(dt['icon'] as IconData, size: 18, color: const Color(0xFF9CC70A)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${match.availableLeaves.toStringAsFixed(1)} Left', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                      Text('${match.allowedLeaves.toStringAsFixed(0)} Allocated', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: percent,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: const Color(0xFF9CC70A),
                      strokeWidth: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 2. MY LEAVE BALANCE SECTION
  // ==========================================
  Widget _buildBalanceSection(List<LeaveBalance> balances, bool isMobile) {
    final defaultTypes = [
      {'type': 'Casual Leave', 'alloc': 12.0, 'used': 4.0, 'cf': 'Up to 5 days', 'expiry': '31 Dec 2026'},
      {'type': 'Sick Leave', 'alloc': 10.0, 'used': 2.0, 'cf': 'Not Allowed', 'expiry': '31 Dec 2026'},
      {'type': 'Annual Leave', 'alloc': 15.0, 'used': 5.0, 'cf': 'Up to 10 days', 'expiry': 'No Expiry'},
      {'type': 'Optional Leave', 'alloc': 3.0, 'used': 1.0, 'cf': 'Not Allowed', 'expiry': '31 Dec 2026'},
      {'type': 'Work From Home', 'alloc': 24.0, 'used': 8.0, 'cf': 'Not Allowed', 'expiry': 'Monthly Reset'},
      {'type': 'Comp Off', 'alloc': 2.0, 'used': 0.0, 'cf': 'Not Allowed', 'expiry': '60 Days'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Leave Balance Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Annual allocation, usage, carry forward rules and expiration terms.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.8 : 2.2,
            ),
            itemCount: defaultTypes.length,
            itemBuilder: (context, idx) {
              final item = defaultTypes[idx];
              final typeName = item['type'].toString();

              final match = balances.firstWhere(
                (b) => b.leaveType.toLowerCase() == typeName.toLowerCase(),
                orElse: () => LeaveBalance(
                  id: 0,
                  employeeId: 0,
                  leaveType: typeName,
                  allowedLeaves: (item['alloc'] as num).toDouble(),
                  usedLeaves: (item['used'] as num).toDouble(),
                  availableLeaves: (item['alloc'] as num).toDouble() - (item['used'] as num).toDouble(),
                  effectiveDate: '',
                  allocationFrequency: 'Annual',
                ),
              );

              final allowed = match.allowedLeaves;
              final used = match.usedLeaves;
              final remaining = match.availableLeaves;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          typeName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Allocated', '${allowed.toStringAsFixed(0)} Days'),
                        _buildStatColumn('Used', '${used.toStringAsFixed(0)} Days'),
                        _buildStatColumn('Remaining', '${remaining.toStringAsFixed(0)} Days', isHighlight: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Carry Forward: ${item['cf']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text('Expiry: ${item['expiry']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String val, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF9CC70A) : const Color(0xFF414A51),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ==========================================
  // 3. APPLY LEAVE SECTION (5-STEP FORM)
  // ==========================================
  Widget _buildApplyLeaveSection(Employee currentEmp, List<LeaveBalance> balances, bool isMobile) {
    double availableForSelected = 12.0;
    final match = balances.where((b) => b.leaveType.toLowerCase() == _selectedLeaveType.toLowerCase()).toList();
    if (match.isNotEmpty) {
      availableForSelected = match.first.availableLeaves;
    }

    final requestedDays = _calculateNumDays();
    final isInsufficient = requestedDays > availableForSelected;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply For Leave',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete the multi-step request form below.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // Stepper Progress Header
              Row(
                children: [1, 2, 3, 4, 5].map((stepNum) {
                  final isActive = _applyStep >= stepNum;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Step Content Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildApplyStepContent(currentEmp, availableForSelected, isInsufficient, requestedDays),
              ),

              const SizedBox(height: 20),

              // Navigation Buttons (Back / Next / Submit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_applyStep > 1)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _applyStep--),
                      icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF414A51)),
                      label: const Text('Back', style: TextStyle(color: Color(0xFF414A51))),
                    )
                  else
                    const SizedBox.shrink(),

                  if (_applyStep < 5)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: const Color(0xFF414A51),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _applyStep++),
                      label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: const Color(0xFF414A51),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _submitRequest(currentEmp, availableForSelected),
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyStepContent(
    Employee currentEmp,
    double availableBalance,
    bool isInsufficient,
    double requestedDays,
  ) {
    switch (_applyStep) {
      case 1:
        final options = [
          {'name': 'Casual Leave', 'desc': 'For planned personal events & leaves'},
          {'name': 'Sick Leave', 'desc': 'For medical emergencies & illness'},
          {'name': 'Annual Leave', 'desc': 'Long vacation and annual holidays'},
          {'name': 'Optional Leave', 'desc': 'Restricted festival holidays'},
          {'name': 'Work From Home', 'desc': 'Remote work day request'},
          {'name': 'Comp Off', 'desc': 'Compensation against extra work days'},
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 1: Choose Leave Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (ctx, idx) {
                final opt = options[idx];
                final isSel = _selectedLeaveType == opt['name'];
                return InkWell(
                  onTap: () => setState(() => _selectedLeaveType = opt['name']!),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF9CC70A).withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: const Color(0xFF414A51),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF414A51))),
                              Text(opt['desc']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 2: Select Dates & Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            const SizedBox(height: 16),
            Row(
              children: [
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
                            setState(() {
                              _fromDate = picked;
                              if (_toDate != null && _toDate!.isBefore(picked)) {
                                _toDate = picked;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fromDate != null ? DateFormat('dd-MM-yyyy').format(_fromDate!) : 'Select Date'),
                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                            initialDate: _toDate ?? DateTime.now(),
                            firstDate: _fromDate ?? DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _toDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_toDate != null ? DateFormat('dd-MM-yyyy').format(_toDate!) : 'Select Date'),
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
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Half Day Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Check if you require only half a working day'),
              value: _isHalfDay,
              activeThumbColor: const Color(0xFF9CC70A),
              onChanged: (val) => setState(() => _isHalfDay = val),
            ),
            if (_isHalfDay) ...[
              const SizedBox(height: 8),
              Row(
                children: ['First Half', 'Second Half'].map((period) {
                  final isSel = _halfDayPeriod == period;
                  return Expanded(
                    child: ChoiceChip(
                      label: Text(period),
                      selected: isSel,
                      selectedColor: const Color(0xFF9CC70A),
                      onSelected: (selected) {
                        if (selected) setState(() => _halfDayPeriod = period);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 3: Leave Reason', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 250,
              decoration: InputDecoration(
                hintText: 'Describe the reason for your leave application...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Emergency Leave Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Mark if this requires immediate manager approval'),
              value: _isEmergency,
              activeColor: const Color(0xFF9CC70A),
              onChanged: (val) => setState(() => _isEmergency = val ?? false),
            ),
          ],
        );

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 4: Supporting Attachment (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            const SizedBox(height: 6),
            const Text('Upload Medical Certificate or supporting documents if applicable.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                setState(() => _attachedFileName = 'Medical_Certificate_Aug2026.pdf');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF9CC70A)),
                    const SizedBox(height: 8),
                    Text(
                      _attachedFileName ?? 'Click to attach PDF / Image document',
                      style: TextStyle(
                        fontWeight: _attachedFileName != null ? FontWeight.bold : FontWeight.normal,
                        color: const Color(0xFF414A51),
                      ),
                    ),
                    if (_attachedFileName != null)
                      TextButton(
                        onPressed: () => setState(() => _attachedFileName = null),
                        child: const Text('Remove Attachment', style: TextStyle(color: Color(0xFFC62828), fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 5:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 5: Review Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
            const SizedBox(height: 16),
            if (isInsufficient)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF5350)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Requested ($requestedDays days) exceeds available balance (${availableBalance.toStringAsFixed(1)} days). Extra days will be marked as Loss of Pay (LOP).',
                        style: const TextStyle(color: Color(0xFFC62828), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            _buildReviewRow('Leave Type', _selectedLeaveType),
            _buildReviewRow('Dates', '${DateFormat('dd MMM').format(_fromDate!)} → ${DateFormat('dd MMM yyyy').format(_toDate!)}'),
            _buildReviewRow('Total Days', '$requestedDays Day(s) ${_isHalfDay ? "($_halfDayPeriod)" : ""}'),
            _buildReviewRow('Current Balance', '${availableBalance.toStringAsFixed(1)} Days'),
            _buildReviewRow('Emergency', _isEmergency ? 'Yes' : 'No'),
            _buildReviewRow('Attachment', _attachedFileName ?? 'None'),
            _buildReviewRow('Reason', _reasonController.text.isEmpty ? 'N/A' : _reasonController.text),
          ],
        );
    }
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF414A51), fontSize: 13)),
        ],
      ),
    );
  }

  // ==========================================
  // 4. MY REQUESTS SECTION
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
                onPressed: () => setState(() => _activeTab = EmployeeLeaveTab.apply),
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
          const SizedBox(height: 12),

          // Approval Timeline Stepper
          _buildApprovalTimeline(req.status),

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
  // 5. CALENDAR SECTION
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
                          mainAxisAlignment: MainAxisAlignment.center,
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
  // 6. LEAVE HISTORY SECTION
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
  // 7. SALARY & LOSS OF PAY (LOP) SECTION
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

  // ==========================================
  // 8. APPROVAL TIMELINE STEPPER
  // ==========================================
  Widget _buildApprovalTimeline(String status) {
    int currentStep = 1;
    bool isRejected = false;
    if (status == 'Approved') {
      currentStep = 4;
    } else if (status == 'Denied' || status == 'Rejected') {
      currentStep = 2;
      isRejected = true;
    } else if (status == 'Pending') {
      currentStep = 2;
    }

    return Row(
      children: [
        _buildTimelineStep('Applied', 1, currentStep, false),
        _buildTimelineLine(1 < currentStep),
        _buildTimelineStep('Manager Review', 2, currentStep, isRejected && currentStep == 2),
        _buildTimelineLine(2 < currentStep),
        _buildTimelineStep('HR Review', 3, currentStep, false),
        _buildTimelineLine(3 < currentStep),
        _buildTimelineStep(isRejected ? 'Rejected' : 'Approved', 4, currentStep, isRejected),
      ],
    );
  }

  Widget _buildTimelineStep(String label, int step, int currentStep, bool isRejected) {
    final isDone = step <= currentStep;
    Color color = const Color(0xFFCBD5E1);
    if (isDone) {
      color = isRejected ? const Color(0xFFC62828) : const Color(0xFF9CC70A);
    }

    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: isDone
                ? Icon(isRejected ? Icons.close : Icons.check, size: 12, color: Colors.white)
                : Text('$step', style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildTimelineLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? const Color(0xFF9CC70A) : const Color(0xFFCBD5E1),
      ),
    );
  }

  // ==========================================
  // 10. PROFILE & LEAVE POLICY SECTION
  // ==========================================
  Widget _buildPolicySection(bool isMobile) {
    final holidays = [
      {'date': '01 Jan 2026', 'day': 'Thursday', 'name': 'New Year Day'},
      {'date': '26 Jan 2026', 'day': 'Monday', 'name': 'Republic Day'},
      {'date': '15 Aug 2026', 'day': 'Saturday', 'name': 'Independence Day'},
      {'date': '02 Oct 2026', 'day': 'Friday', 'name': 'Gandhi Jayanti'},
      {'date': '25 Dec 2026', 'day': 'Friday', 'name': 'Christmas'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Company Leave Policy & Holidays', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
          const SizedBox(height: 16),

          // Policy Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leave Rules Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text('• Casual Leaves must be applied at least 24 hours prior.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text('• Sick leaves exceeding 2 consecutive days require a medical certificate.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Text('• Carry forward of up to 5 unused Casual Leaves is allowed at year end.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Upcoming Company Holidays', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: holidays.length,
            itemBuilder: (ctx, idx) {
              final h = holidays[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.celebration, color: Color(0xFF9CC70A), size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(h['day']!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                    Text(h['date']!, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF414A51))),
                  ],
                ),
              );
            },
          ),
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

  void _showContactHrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact HR Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: hr@company.com'),
            SizedBox(height: 4),
            Text('Phone: +91 98765 43210'),
            SizedBox(height: 4),
            Text('Office Hours: 9:00 AM - 6:00 PM (Mon-Fri)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
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
