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
      appBar: AppBar(
        title: const Text(
          'Permission Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AdminPermissionManagementPage.darkNeutral,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Requests',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AdminPermissionManagementPage.primaryGreen,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Emergency'),
            Tab(text: 'Usage Tracker'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AdminPermissionManagementPage.primaryGreen,
            child: Text(
              req.employeeName.isNotEmpty ? req.employeeName[0].toUpperCase() : 'E',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        req.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminPermissionManagementPage.darkNeutral),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        req.status == PermissionStatus.emergencyPending
                            ? 'Emergency Pending'
                            : (req.isEmergency ? 'Emergency' : req.status.label),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${req.employeeCode} • ${req.department}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${req.fromTime} - ${req.toTime} (${req.durationMinutes}m)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Reason: ${req.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => AdminRequestReviewDialog(request: req),
              );
              if (result == true) {
                _refreshData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPermissionManagementPage.darkNeutral,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
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
