import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/permission_enums.dart';
import '../domain/permission_request.dart';
import '../providers/permission_providers.dart';
import 'admin_permission_settings_page.dart';
import 'admin_permission_usage_page.dart';
import 'admin_request_review_dialog.dart';

class AdminPermissionManagementPage extends ConsumerStatefulWidget {
  const AdminPermissionManagementPage({super.key});

  static const Color primaryGreen = Color(0xFF9CC70A);
  static const Color darkNeutral = Color(0xFF414A51);

  @override
  ConsumerState<AdminPermissionManagementPage> createState() => _AdminPermissionManagementPageState();
}

class _AdminPermissionManagementPageState extends ConsumerState<AdminPermissionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedDepartment = 'All Departments';
  PermissionStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        ref.read(adminPermissionActiveTabProvider.notifier).state = _tabController.index;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    ref.invalidate(allPermissionRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filter = AllPermissionRequestsFilter(
      department: _selectedDepartment == 'All Departments' ? null : _selectedDepartment,
      status: _statusFilter,
    );

    final allRequestsAsync = ref.watch(allPermissionRequestsProvider(filter));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Standard & All Requests
          _buildRequestsTab(allRequestsAsync, isEmergencyOnly: false),

          // Tab 2: Emergency Requests Only
          _buildRequestsTab(allRequestsAsync, isEmergencyOnly: true),

          // Tab 3: Usage Tracker
          const AdminPermissionUsagePage(),

          // Tab 4: Policy Settings
          const AdminPermissionSettingsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AdminPermissionManagementPage.primaryGreen,
              indicatorWeight: 3,
              labelColor: AdminPermissionManagementPage.primaryGreen,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_outlined, size: 22),
                  text: 'Requests',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.warning_amber_rounded, size: 22),
                  text: 'Emergency',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.bar_chart_outlined, size: 22),
                  text: 'Usage',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.settings_outlined, size: 22),
                  text: 'Settings',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTab(AsyncValue<List<PermissionRequest>> requestsAsync, {required bool isEmergencyOnly}) {
    return Column(
      children: [
        // Summary Cards
        requestsAsync.maybeWhen(
          data: (requests) => _buildMetricsHeader(requests),
          orElse: () => const SizedBox.shrink(),
        ),

        // Filter Bar (Departments & Status filter)
        if (!isEmergencyOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDepartment,
                        isExpanded: true,
                        items: ['All Departments', 'Management', 'Engineering', 'Operations', 'Sales', 'HR']
                            .map((dept) => DropdownMenuItem(value: dept, child: Text(dept)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDepartment = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PermissionStatus?>(
                        value: _statusFilter,
                        hint: const Text('All Statuses'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Statuses')),
                          ...PermissionStatus.values.map(
                            (st) => DropdownMenuItem(value: st, child: Text(st.label)),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _statusFilter = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Requests List
        Expanded(
          child: requestsAsync.when(
            data: (allRequests) {
              final filtered = isEmergencyOnly
                  ? allRequests.where((r) => r.isEmergency || r.status == PermissionStatus.emergencyPending).toList()
                  : allRequests;

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        isEmergencyOnly ? 'No emergency requests pending review' : 'No permission requests found',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final req = filtered[index];
                  return _buildAdminRequestCard(req);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsHeader(List<PermissionRequest> requests) {
    final pendingCount = requests.where((r) => r.status == PermissionStatus.pending).length;
    final emergencyCount = requests.where((r) => r.isEmergency || r.status == PermissionStatus.emergencyPending).length;
    final approvedCount = requests.where((r) => r.status == PermissionStatus.approved).length;
    final rejectedCount = requests.where((r) => r.status == PermissionStatus.rejected).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Pending', pendingCount.toString(), Colors.blue.shade700)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('Emergency', emergencyCount.toString(), Colors.orange.shade800)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('Approved', approvedCount.toString(), AdminPermissionManagementPage.primaryGreen)),
          const SizedBox(width: 8),
          Expanded(child: _buildMetricCard('Rejected', rejectedCount.toString(), Colors.red.shade700)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String count, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminRequestCard(PermissionRequest req) {
    Color statusColor;
    switch (req.status) {
      case PermissionStatus.approved:
        statusColor = Colors.green.shade700;
        break;
      case PermissionStatus.rejected:
        statusColor = Colors.red.shade700;
        break;
      case PermissionStatus.emergencyPending:
        statusColor = Colors.orange.shade800;
        break;
      case PermissionStatus.cancelled:
        statusColor = Colors.grey.shade600;
        break;
      case PermissionStatus.pending:
      default:
        statusColor = Colors.blue.shade700;
        break;
    }

    final dateStr = '${req.date.day} ${_getMonthAbbr(req.date.month)} ${req.date.year}';
    final initials = req.employeeName.isNotEmpty
        ? req.employeeName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'E';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Avatar, Name, ID, Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFFFF3E0),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AdminPermissionManagementPage.darkNeutral,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${req.employeeCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    req.status == PermissionStatus.emergencyPending
                        ? 'Emergency Pending'
                        : (req.isEmergency ? 'Emergency' : req.status.label),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Department & Category Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTagChip(Icons.business_outlined, req.department),
                _buildTagChip(Icons.category_outlined, req.permissionType.label),
                _buildTagChip(Icons.calendar_today_outlined, dateStr),
                _buildTagChip(Icons.access_time_outlined, '${req.fromTime} - ${req.toTime} (${req.durationMinutes}m)'),
              ],
            ),
          ),

          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reason: ${req.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bottom Action Banner: "Review Request Details >"
          InkWell(
            onTap: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => AdminRequestReviewDialog(request: req),
              );
              if (result == true) {
                _refreshData();
              }
            },
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Review Request Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminPermissionManagementPage.darkNeutral,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
