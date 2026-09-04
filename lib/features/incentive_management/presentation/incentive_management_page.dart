import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_settings.dart';
import '../../incentive/providers/incentive_providers.dart';
import '../providers/incentive_management_providers.dart';
import 'widgets/incentive_column_selection_dialog.dart';

String formatIndianCurrency(num amount, {String symbol = 'Rs '}) {
  final intVal = amount.round();
  final str = intVal.abs().toString();
  if (str.length <= 3) {
    return '$symbol${intVal < 0 ? '-' : ''}$str';
  }
  final last3 = str.substring(str.length - 3);
  final otherNumbers = str.substring(0, str.length - 3);
  final formattedOther = otherNumbers.replaceAllMapped(
    RegExp(r'(\d+?)(?=(\d{2})+$)'),
    (Match m) => '${m[1]},',
  );
  return '$symbol${intVal < 0 ? '-' : ''}$formattedOther,$last3';
}

class EmployeeIncentiveGroup {
  final String key;
  final String employeeName;
  final int? employeeId;
  final String designation;
  final List<IncentiveRequest> requests;

  EmployeeIncentiveGroup({
    required this.key,
    required this.employeeName,
    this.employeeId,
    required this.designation,
    required this.requests,
  });

  double get totalAmount => requests.fold(0.0, (sum, r) => sum + (r.approvedAmount ?? r.amount));
}

class IncentiveManagementPage extends ConsumerStatefulWidget {
  const IncentiveManagementPage({super.key});

  @override
  ConsumerState<IncentiveManagementPage> createState() => _IncentiveManagementPageState();
}

class _IncentiveManagementPageState extends ConsumerState<IncentiveManagementPage> {
  IncentiveRequest? _selectedRequest;
  final Set<int> _selectedBulkIds = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _verifiedMetersController = TextEditingController();
  final TextEditingController _approvedAmountController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBar = false;

  @override
  void dispose() {
    _searchController.dispose();
    _verifiedMetersController.dispose();
    _approvedAmountController.dispose();
    super.dispose();
  }

  List<EmployeeIncentiveGroup> _groupRequestsByEmployee(List<IncentiveRequest> requests) {
    final Map<String, List<IncentiveRequest>> map = {};
    final Map<String, IncentiveRequest> firstMap = {};

    for (final req in requests) {
      final key = (req.employeeId != null && req.employeeId! > 0)
          ? 'EMP_${req.employeeId}'
          : req.employeeName.trim().toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = [];
        firstMap[key] = req;
      }
      map[key]!.add(req);
    }

    return map.entries.map((e) {
      final first = firstMap[e.key]!;
      return EmployeeIncentiveGroup(
        key: e.key,
        employeeName: first.employeeName,
        employeeId: first.employeeId,
        designation: first.designation,
        requests: e.value,
      );
    }).toList();
  }

  Future<void> _showSubmissionLockSettingsDialog() async {
    final currentSettings = await ref.read(incentiveManagementRepositoryProvider).getIncentiveSettings();
    if (!mounted) return;

    bool isLockActive = currentSettings.isLockActive;
    final fromDateController = TextEditingController(
      text: (currentSettings.lockFromDate != null && currentSettings.lockFromDate.isNotEmpty)
          ? currentSettings.lockFromDate
          : DateTime.now().toIso8601String().substring(0, 10),
    );
    final toDateController = TextEditingController(
      text: (currentSettings.lockToDate != null && currentSettings.lockToDate.isNotEmpty)
          ? currentSettings.lockToDate
          : DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.lock_clock_outlined, color: AppColors.active),
                  SizedBox(width: 8),
                  Text('Submission Restriction Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lock user incentive submissions during a specific date window.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Submission Lockout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Block users from submitting incentive requests during the date range', style: TextStyle(fontSize: 12)),
                      value: isLockActive,
                      activeColor: AppColors.active,
                      onChanged: (val) {
                        setDialogState(() => isLockActive = val);
                      },
                    ),
                    const Divider(height: 24),

                    const Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fromDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(fromDateController.text) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                fromDateController.text = picked.toIso8601String().substring(0, 10);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: toDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(toDateController.text) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                toDateController.text = picked.toIso8601String().substring(0, 10);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newSettings = IncentiveSettings(
                      isLockActive: isLockActive,
                      lockFromDate: fromDateController.text.trim(),
                      lockToDate: toDateController.text.trim(),
                    );
                    await ref.read(incentiveManagementRepositoryProvider).updateIncentiveSettings(newSettings);
                    ref.invalidate(incentiveSettingsProvider);

                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Submission restriction settings saved!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectRequest(IncentiveRequest req) {
    setState(() {
      _selectedRequest = req;
      _verifiedMetersController.text = req.verifiedMeters?.toInt().toString() ?? req.meters.toInt().toString();
      _approvedAmountController.text = req.approvedAmount?.toInt().toString() ?? req.amount.toInt().toString();
    });
  }

  Future<void> _handleApprove([IncentiveRequest? requestToApprove]) async {
    final target = requestToApprove ?? _selectedRequest;
    if (target == null || target.id == null) return;

    final verifiedMeters = double.tryParse(_verifiedMetersController.text.trim()) ?? (target.verifiedMeters ?? target.meters);
    final approvedAmount = double.tryParse(_approvedAmountController.text.trim()) ?? (verifiedMeters * target.rate);

    try {
      await ref.read(incentiveManagementRepositoryProvider).approveRequest(
            target.id!,
            verifiedMeters,
            approvedAmount,
          );
      ref.invalidate(allManagementRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incentive request for ${target.employeeName} approved!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        setState(() {
          _selectedRequest = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleReject([IncentiveRequest? requestToReject]) async {
    final target = requestToReject ?? _selectedRequest;
    if (target == null || target.id == null) return;

    try {
      await ref.read(incentiveManagementRepositoryProvider).rejectRequest(target.id!);
      ref.invalidate(allManagementRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incentive request for ${target.employeeName} rejected.'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        setState(() {
          _selectedRequest = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleBulkApprove() async {
    if (_selectedBulkIds.isEmpty) return;
    final repo = ref.read(incentiveManagementRepositoryProvider);

    try {
      final allReqs = await repo.getAllRequests();
      for (final id in _selectedBulkIds) {
        final req = allReqs.firstWhere((r) => r.id == id, orElse: () => allReqs.first);
        await repo.approveRequest(id, req.verifiedMeters ?? req.meters, req.approvedAmount ?? req.amount);
      }
      ref.invalidate(allManagementRequestsProvider);

      if (mounted) {
        final count = _selectedBulkIds.length;
        setState(() {
          _selectedBulkIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count incentive requests approved successfully!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error in bulk approval: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleBulkReject() async {
    if (_selectedBulkIds.isEmpty) return;
    final repo = ref.read(incentiveManagementRepositoryProvider);

    try {
      for (final id in _selectedBulkIds) {
        await repo.rejectRequest(id);
      }
      ref.invalidate(allManagementRequestsProvider);

      if (mounted) {
        final count = _selectedBulkIds.length;
        setState(() {
          _selectedBulkIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count incentive requests rejected.'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error in bulk rejection: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 700) {
          return _buildMobileView(context);
        } else {
          return _buildDesktopView(context);
        }
      },
    );
  }

  // Mobile View with Grouped Employee Cards
  Widget _buildMobileView(BuildContext context) {
    final requestsAsync = ref.watch(allManagementRequestsProvider);
    final activeTab = ref.watch(incentiveManagementTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar - Search and Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  // Visible Search Box
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by employee, designation, or site...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Actions Menu Button
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.active),
                      onSelected: (val) {
                        if (val == 'columns') {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const IncentiveColumnSelectionDialog(),
                          );
                        } else if (val == 'lock') {
                          _showSubmissionLockSettingsDialog();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'columns',
                          child: Row(
                            children: [
                              Icon(Icons.view_column_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Columns'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'lock',
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Submission restriction'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area
            Expanded(
              child: requestsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                data: (allRequests) {
                  final pendingList = allRequests.where((r) => r.status == 'Pending').toList();
                  final approvedList = allRequests.where((r) => r.status == 'Approved').toList();
                  final rejectedList = allRequests.where((r) => r.status == 'Rejected').toList();

                  List<IncentiveRequest> currentTabRequests = [];
                  if (activeTab == 'Pending') {
                    currentTabRequests = pendingList;
                  } else if (activeTab == 'Approved') {
                    currentTabRequests = approvedList;
                  } else {
                    currentTabRequests = rejectedList;
                  }

                  final filteredTabRequests = currentTabRequests.where((req) {
                    if (_searchQuery.trim().isEmpty) return true;
                    final q = _searchQuery.toLowerCase().trim();
                    final empIdCode = req.employeeId != null
                        ? 'emp${req.employeeId.toString().padLeft(3, '0')}'
                        : '';
                    return req.employeeName.toLowerCase().contains(q) ||
                        empIdCode.contains(q) ||
                        req.designation.toLowerCase().contains(q) ||
                        req.site.toLowerCase().contains(q) ||
                        req.productName.toLowerCase().contains(q) ||
                        req.requestId.toLowerCase().contains(q);
                  }).toList();

                  final groupedList = _groupRequestsByEmployee(filteredTabRequests);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Horizontal Scrollable Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _buildMobileFilterChip('Pending', pendingList.length),
                            const SizedBox(width: 8),
                            _buildMobileFilterChip('Approved', approvedList.length),
                            const SizedBox(width: 8),
                            _buildMobileFilterChip('Rejected', rejectedList.length),
                          ],
                        ),
                      ),

                      // Subtitle count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          '${groupedList.length} ${groupedList.length == 1 ? 'employee' : 'employees'} (${filteredTabRequests.length} ${activeTab.toLowerCase()} requests)',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Grouped Employee Cards List
                      Expanded(
                        child: groupedList.isEmpty
                            ? Center(
                                child: Text(
                                  'No $activeTab incentive requests found.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: groupedList.length,
                                itemBuilder: (context, index) {
                                  final group = groupedList[index];
                                  return _buildGroupedEmployeeCard(group);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedEmployeeCard(EmployeeIncentiveGroup group) {
    final empIdStr = group.employeeId != null
        ? 'EMP${group.employeeId.toString().padLeft(3, '0')}'
        : '';
    final reqCountText = '${group.requests.length} ${group.requests.length == 1 ? 'Request' : 'Requests'}';

    void openEmployeeRequests() {
      final activeTab = ref.read(incentiveManagementTabProvider);
      final empIdParam = group.employeeId != null ? group.employeeId.toString() : '';
      context.push(
        '/incentive-management/employee-requests?employeeId=$empIdParam&employeeName=${Uri.encodeComponent(group.employeeName)}&designation=${Uri.encodeComponent(group.designation)}&status=$activeTab',
      );
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: openEmployeeRequests,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Employee Name + Requests Badge + Subtitle
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0D47A1),
                    child: Text(
                      _getInitials(group.employeeName),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                reqCountText,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$empIdStr · ${group.designation}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom row: Total Combined Amount + "View Requests" Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Combined Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatIndianCurrency(group.totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.active,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.active),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: openEmployeeRequests,
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    label: const Text('View Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFilterChip(String tabName, int count) {
    final activeTab = ref.watch(incentiveManagementTabProvider);
    final isSelected = activeTab == tabName;

    return ChoiceChip(
      label: Text(
        '$tabName ($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1E293B),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onSelected: (_) {
        ref.read(incentiveManagementTabProvider.notifier).state = tabName;
        setState(() {
          _selectedRequest = null;
          _selectedBulkIds.clear();
        });
      },
    );
  }

  // Desktop View (100% Width Table)
  Widget _buildDesktopView(BuildContext context) {
    final requestsAsync = ref.watch(allManagementRequestsProvider);
    final activeTab = ref.watch(incentiveManagementTabProvider);
    final visibleColumns = ref.watch(incentiveVisibleColumnsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      bottomNavigationBar: _selectedBulkIds.isNotEmpty
          ? Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedBulkIds.length} requests selected',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _handleBulkApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve all', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleBulkReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject all', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    tooltip: 'Clear selection',
                    onPressed: () {
                      setState(() {
                        _selectedBulkIds.clear();
                      });
                    },
                  ),
                ],
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                return isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assignment_turned_in_outlined, color: AppColors.active, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Incentive management',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Review, verify and approve incentive requests submitted by employees.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF414A51),
                                  side: const BorderSide(color: Color(0xFF414A51)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.view_column_outlined, size: 18),
                                label: const Text('Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => const IncentiveColumnSelectionDialog(),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF414A51),
                                  side: const BorderSide(color: Color(0xFF414A51)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.lock_clock_outlined, size: 18),
                                label: const Text('Submission restriction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: _showSubmissionLockSettingsDialog,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.assignment_turned_in_outlined, color: AppColors.active, size: 28),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Incentive management',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Review, verify and approve incentive requests submitted by employees.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF414A51),
                              side: const BorderSide(color: Color(0xFF414A51)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.view_column_outlined, size: 18),
                            label: const Text('Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const IncentiveColumnSelectionDialog(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF414A51),
                              side: const BorderSide(color: Color(0xFF414A51)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.lock_clock_outlined, size: 18),
                            label: const Text('Submission restriction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showSubmissionLockSettingsDialog,
                          ),
                        ],
                      );
              },
            ),
            const SizedBox(height: 20),

            requestsAsync.when(
              data: (allRequests) {
                final pendingList = allRequests.where((r) => r.status == 'Pending').toList();
                final approvedList = allRequests.where((r) => r.status == 'Approved').toList();
                final rejectedList = allRequests.where((r) => r.status == 'Rejected').toList();

                List<IncentiveRequest> currentTabRequests = [];
                if (activeTab == 'Pending') {
                  currentTabRequests = pendingList;
                } else if (activeTab == 'Approved') {
                  currentTabRequests = approvedList;
                } else {
                  currentTabRequests = rejectedList;
                }

                final filteredTabRequests = currentTabRequests.where((req) {
                  if (_searchQuery.trim().isEmpty) return true;
                  final q = _searchQuery.toLowerCase().trim();
                  final empIdCode = req.employeeId != null
                      ? 'emp${req.employeeId.toString().padLeft(3, '0')}'
                      : '';
                  return req.employeeName.toLowerCase().contains(q) ||
                      empIdCode.contains(q) ||
                      req.designation.toLowerCase().contains(q) ||
                      req.site.toLowerCase().contains(q) ||
                      req.productName.toLowerCase().contains(q) ||
                      req.requestId.toLowerCase().contains(q);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Filter Tabs & Search Bar
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFilterTab('Pending', pendingList.length),
                            const SizedBox(width: 10),
                            _buildFilterTab('Approved', approvedList.length),
                            const SizedBox(width: 10),
                            _buildFilterTab('Rejected', rejectedList.length),
                          ],
                        ),
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by employee, ID, site...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: (_searchQuery.isNotEmpty)
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Table Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 64,
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                              horizontalMargin: 20,
                              columnSpacing: 24,
                              onSelectAll: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedBulkIds.addAll(
                                      filteredTabRequests.map((r) => r.id!).whereType<int>(),
                                    );
                                  } else {
                                    _selectedBulkIds.clear();
                                  }
                                });
                              },
                              columns: visibleColumns.map((col) {
                                return DataColumn(
                                  numeric: col == 'Amount',
                                  label: Text(
                                    col,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                );
                              }).toList(),
                              rows: filteredTabRequests.map((req) {
                                final isBulkSelected = req.id != null && _selectedBulkIds.contains(req.id);
                                final empIdStr = req.employeeId != null
                                    ? 'EMP${req.employeeId.toString().padLeft(3, '0')}'
                                    : '';

                                return DataRow(
                                  selected: isBulkSelected,
                                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (isBulkSelected) {
                                      return const Color(0xFFEFF6FF);
                                    }
                                    return null;
                                  }),
                                  onSelectChanged: (val) {
                                    setState(() {
                                      if (val == true && req.id != null) {
                                        _selectedBulkIds.add(req.id!);
                                        _selectRequest(req);
                                      } else if (req.id != null) {
                                        _selectedBulkIds.remove(req.id!);
                                      }
                                    });
                                  },
                                  cells: visibleColumns.map((col) {
                                    switch (col) {
                                      case 'Emp ID':
                                        return DataCell(
                                          Text(
                                            empIdStr,
                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                        );
                                      case 'Employee':
                                        return DataCell(
                                          Text(
                                            req.employeeName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                          ),
                                        );
                                      case 'Designation':
                                        return DataCell(
                                          Text(
                                            req.designation.isNotEmpty ? req.designation : '-',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                        );
                                      case 'Site':
                                        return DataCell(Text(req.site, style: const TextStyle(fontSize: 13)));
                                      case 'Amount':
                                        return DataCell(
                                          Text(
                                            formatIndianCurrency(req.approvedAmount ?? req.amount),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        );
                                      case 'Status':
                                        return DataCell(_buildStatusBadge(req.status));
                                      case 'Action':
                                        return DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  _selectRequest(req);
                                                  context.push('/incentive-management/detail/${req.id}');
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF1967D2),
                                                  side: const BorderSide(color: Color(0xFF1967D2)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                ),
                                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                                label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                              if (req.status == 'Pending') ...[
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.check, color: Color(0xFF16A34A), size: 20),
                                                  tooltip: 'Approve',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  onPressed: () {
                                                    _selectRequest(req);
                                                    _handleApprove(req);
                                                  },
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.close, color: Color(0xFFE53935), size: 20),
                                                  tooltip: 'Reject',
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                  onPressed: () {
                                                    _selectRequest(req);
                                                    _handleReject(req);
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      default:
                                        return const DataCell(Text('-'));
                                    }
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
                          if (filteredTabRequests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(36.0),
                              child: Center(
                                child: Text(
                                  'No $activeTab incentive requests found.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Tick checkboxes to bulk approve or reject multiple requests at once',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('Error loading requests: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String tabName, int count) {
    final activeTab = ref.watch(incentiveManagementTabProvider);
    final isSelected = activeTab == tabName;

    return InkWell(
      onTap: () {
        ref.read(incentiveManagementTabProvider.notifier).state = tabName;
        setState(() {
          _selectedRequest = null;
          _selectedBulkIds.clear();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade300,
            width: 1.0,
          ),
        ),
        child: Text(
          '$tabName ($count)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFFF3E0);
    Color fg = const Color(0xFFE65100);

    if (status == 'Approved') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (status == 'Rejected') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
