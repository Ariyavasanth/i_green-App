import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_settings.dart';
import '../../incentive/providers/incentive_providers.dart';
import '../providers/incentive_management_providers.dart';

class IncentiveManagementPage extends ConsumerStatefulWidget {
  const IncentiveManagementPage({super.key});

  @override
  ConsumerState<IncentiveManagementPage> createState() => _IncentiveManagementPageState();
}

class _IncentiveManagementPageState extends ConsumerState<IncentiveManagementPage> {
  IncentiveRequest? _selectedRequest;
  final TextEditingController _verifiedMetersController = TextEditingController();
  final TextEditingController _approvedAmountController = TextEditingController();

  @override
  void dispose() {
    _verifiedMetersController.dispose();
    _approvedAmountController.dispose();
    super.dispose();
  }

  Future<void> _showSubmissionLockSettingsDialog() async {
    final currentSettings = await ref.read(incentiveManagementRepositoryProvider).getIncentiveSettings();
    if (!mounted) return;

    bool isLockActive = currentSettings.isLockActive;
    final fromDateController = TextEditingController(
      text: currentSettings.lockFromDate.isNotEmpty
          ? currentSettings.lockFromDate
          : DateTime.now().toIso8601String().substring(0, 10),
    );
    final toDateController = TextEditingController(
      text: currentSettings.lockToDate.isNotEmpty
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

  void _onVerifiedMetersChanged(String val) {
    if (_selectedRequest == null) return;
    final meters = double.tryParse(val.trim()) ?? 0.0;
    final calcAmount = meters * _selectedRequest!.rate;
    _approvedAmountController.text = calcAmount.toInt().toString();
  }

  Future<void> _handleApprove([IncentiveRequest? requestToApprove]) async {
    final target = requestToApprove ?? _selectedRequest;
    if (target == null || target.id == null) return;

    final verifiedMeters = double.tryParse(_verifiedMetersController.text.trim()) ?? target.meters;
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
            content: Text('Request for ${target.employeeName} approved!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
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
            content: Text('Request for ${target.employeeName} rejected.'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allManagementRequestsProvider);
    final activeTab = ref.watch(incentiveManagementTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.price_check_outlined, color: AppColors.active, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Incentive Management',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showSubmissionLockSettingsDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.lock_clock_outlined, size: 18),
                  label: const Text('Submission Restriction Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
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

                // Default selection to first request if none selected or not in current list
                if (currentTabRequests.isNotEmpty) {
                  if (_selectedRequest == null || !currentTabRequests.any((r) => r.id == _selectedRequest?.id)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _selectRequest(currentTabRequests.first);
                    });
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Filter Tabs (matching Image 1)
                    Row(
                      children: [
                        _buildFilterTab('Pending', pendingList.length),
                        const SizedBox(width: 12),
                        _buildFilterTab('Approved', approvedList.length),
                        const SizedBox(width: 12),
                        _buildFilterTab('Rejected', rejectedList.length),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Table Card (matching Image 1)
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                              horizontalMargin: 20,
                              columnSpacing: 30,
                              columns: const [
                                DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Site', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Meters', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Rate (₹/m)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: currentTabRequests.map((req) {
                                final isSelected = _selectedRequest?.id == req.id;
                                return DataRow(
                                  selected: isSelected,
                                  onSelectChanged: (_) => _selectRequest(req),
                                  cells: [
                                    DataCell(Text(req.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(req.site)),
                                    DataCell(Text(req.meters.toInt().toString())),
                                    DataCell(Text(req.rate.toInt().toString())),
                                    DataCell(Text(
                                      req.amount >= 1000
                                          ? '${(req.amount / 1000).toStringAsFixed(1).replaceAll('.0', '')},${(req.amount % 1000).toInt().toString().padLeft(3, '0')}'
                                          : req.amount.toInt().toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )),
                                    DataCell(_buildStatusBadge(req.status)),
                                    DataCell(
                                      req.status == 'Pending'
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _selectRequest(req);
                                                    _handleApprove(req);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF2E7D32),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _selectRequest(req);
                                                    _handleReject(req);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFC62828),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              req.status == 'Approved' ? 'Verified' : 'Processed',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          if (currentTabRequests.isEmpty)
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
                    const SizedBox(height: 24),

                    // Bottom Dual Card Layout (matching Image 1)
                    if (_selectedRequest != null)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          return isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildRequestDetailsCard(_selectedRequest!)),
                                    const SizedBox(width: 24),
                                    Expanded(child: _buildVerifyApproveCard(_selectedRequest!)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildRequestDetailsCard(_selectedRequest!),
                                    const SizedBox(height: 24),
                                    _buildVerifyApproveCard(_selectedRequest!),
                                  ],
                                );
                        },
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
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1967D2) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          '$tabName ($count)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1967D2) : Colors.grey.shade700,
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

  Widget _buildRequestDetailsCard(IncentiveRequest req) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Employee', ': ${req.employeeName}'),
            _buildDetailRow('Site', ': ${req.site}'),
            _buildDetailRow('Work Type', ': ${req.productName}'),
            _buildDetailRow('Total Meters', ': ${req.meters.toInt()} m'),
            _buildDetailRow('Incentive Rate', ': ₹${req.rate.toInt()} per meter'),
            _buildDetailRow('Requested Amount', ': ₹${req.amount.toInt()}'),
            _buildDetailRow('Remarks', ': ${req.remarks ?? '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyApproveCard(IncentiveRequest req) {
    final isPending = req.status == 'Pending';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify & Approve',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36)),
            ),
            const SizedBox(height: 20),

            // Verified Meters (in meters)
            const Text(
              'Verified Meters (in meters)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _verifiedMetersController,
              enabled: isPending,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: isPending ? Colors.white : Colors.grey.shade100,
              ),
              onChanged: _onVerifiedMetersChanged,
            ),
            const SizedBox(height: 16),

            // Approved Amount (₹)
            const Text(
              'Approved Amount (₹)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _approvedAmountController,
              enabled: isPending,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: isPending ? Colors.grey.shade100 : Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 24),

            // Approve / Reject buttons (matching Image 1)
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleApprove(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleReject(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      req.status == 'Approved' ? Icons.check_circle : Icons.cancel,
                      color: req.status == 'Approved' ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Request status: ${req.status}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
