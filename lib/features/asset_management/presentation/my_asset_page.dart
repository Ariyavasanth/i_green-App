import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/asset_assignment.dart';
import '../domain/asset_transfer_request.dart';
import '../providers/asset_management_providers.dart';

class MyAssetPage extends ConsumerStatefulWidget {
  const MyAssetPage({super.key});

  @override
  ConsumerState<MyAssetPage> createState() => _MyAssetPageState();
}

class _MyAssetPageState extends ConsumerState<MyAssetPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getAssetIcon(String assetTypeName) {
    final name = assetTypeName.toLowerCase();
    if (name.contains('laptop') || name.contains('macbook') || name.contains('computer')) {
      return Icons.laptop_mac_outlined;
    } else if (name.contains('phone') || name.contains('mobile') || name.contains('smartphone')) {
      return Icons.phone_android_outlined;
    } else if (name.contains('tablet') || name.contains('ipad')) {
      return Icons.tablet_mac_outlined;
    } else if (name.contains('monitor') || name.contains('screen') || name.contains('display')) {
      return Icons.desktop_windows_outlined;
    } else if (name.contains('key') || name.contains('card') || name.contains('badge') || name.contains('id')) {
      return Icons.badge_outlined;
    } else if (name.contains('car') || name.contains('vehicle') || name.contains('bike')) {
      return Icons.directions_car_outlined;
    } else if (name.contains('headset') || name.contains('headphone') || name.contains('audio')) {
      return Icons.headset_outlined;
    }
    return Icons.devices_other_outlined;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Assigned':
        return const Color(0xFF9CC70A);
      case 'Maintenance':
        return const Color(0xFFFF9800);
      case 'Returned':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF414A51);
    }
  }



  // ── Maintenance Dialog (Matching Exact Reference Screenshot Layout) ─────────────────────
  Future<void> _showMaintenanceDialog(AssetAssignment asset) async {
    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController(text: asset.description);
    String selectedStatus = asset.status == 'Maintenance' ? 'Maintenance' : 'Maintenance';
    final maintAddressController = TextEditingController(text: asset.maintenanceAddress ?? '');
    final maintContactController = TextEditingController(text: asset.maintenanceContact ?? '');
    final now = DateTime.now();
    final maintGivenDateController = TextEditingController(
      text: asset.maintenanceGivenDate ?? DateFormat('yyyy-MM-dd').format(now),
    );
    final maintReturnDateController = TextEditingController(
      text: asset.maintenanceReturnDate ?? DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7))),
    );

    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isMaint = selectedStatus == 'Maintenance';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.build_circle_outlined, color: Color(0xFFFF9800), size: 24),
                  SizedBox(width: 10),
                  Text('Maintenance Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reason for Assignment / Description *
                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Reason for Assignment / Description *',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter description / reason';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Assignment Status Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Assignment Status',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                            DropdownMenuItem(value: 'Returned', child: Text('Returned')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedStatus = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Maintenance Details Container (Matching Screenshot Exactly)
                        if (isMaint) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.build_circle_outlined, color: Color(0xFFFF9800), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Maintenance Details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Maintenance Place Address *
                                TextFormField(
                                  controller: maintAddressController,
                                  decoration: InputDecoration(
                                    labelText: 'Maintenance Place Address *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (isMaint && (val == null || val.trim().isEmpty)) {
                                      return 'Please enter maintenance address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Contact Number *
                                TextFormField(
                                  controller: maintContactController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Contact Number *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (isMaint && (val == null || val.trim().isEmpty)) {
                                      return 'Please enter contact number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Row: Given Date * and Return Date *
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: maintGivenDateController,
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'Given Date *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          isDense: true,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                                            onPressed: () async {
                                              final curDate = DateTime.tryParse(maintGivenDateController.text) ?? DateTime.now();
                                              final picked = await showDatePicker(
                                                context: dialogCtx,
                                                initialDate: curDate,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2035),
                                              );
                                              if (picked != null) {
                                                setDialogState(() {
                                                  maintGivenDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        validator: (val) {
                                          if (isMaint && (val == null || val.trim().isEmpty)) {
                                            return 'Given date required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: maintReturnDateController,
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'Return Date *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          isDense: true,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                                            onPressed: () async {
                                              final curDate = DateTime.tryParse(maintReturnDateController.text) ?? DateTime.now().add(const Duration(days: 7));
                                              final picked = await showDatePicker(
                                                context: dialogCtx,
                                                initialDate: curDate,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2035),
                                              );
                                              if (picked != null) {
                                                setDialogState(() {
                                                  maintReturnDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        validator: (val) {
                                          if (isMaint && (val == null || val.trim().isEmpty)) {
                                            return 'Return date required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final updated = asset.copyWith(
                              description: descController.text.trim(),
                              status: selectedStatus,
                              maintenanceAddress: isMaint ? maintAddressController.text.trim() : null,
                              maintenanceContact: isMaint ? maintContactController.text.trim() : null,
                              maintenanceGivenDate: isMaint ? maintGivenDateController.text.trim() : null,
                              maintenanceReturnDate: isMaint ? maintReturnDateController.text.trim() : null,
                            );

                            await ref.read(assetAssignmentRepositoryProvider).updateAssignment(updated);
                            ref.refresh(assetAssignmentsProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text('Asset maintenance details updated successfully.'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF9CC70A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error updating maintenance details: $e')),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Details'),
                ),
              ],
            );
          },
        );
      },
    );

    descController.dispose();
    maintAddressController.dispose();
    maintContactController.dispose();
    maintGivenDateController.dispose();
    maintReturnDateController.dispose();
  }

  // ── Transfer Asset Dialog ─────────────────────────────────────────────────────────────
  Future<void> _showTransferDialog(AssetAssignment asset, List<Employee> employees) async {
    final formKey = GlobalKey<FormState>();
    Employee? selectedTargetEmployee;
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final transferDateController = TextEditingController(text: nowStr);
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    // Filter out current assigned employee
    final availableEmployees = employees.where((e) => e.id != asset.employeeId).toList();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.swap_horiz_outlined, color: Color(0xFF9CC70A), size: 24),
                  SizedBox(width: 10),
                  Text('Transfer Asset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Asset Summary Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(_getAssetIcon(asset.assetTypeName), color: const Color(0xFF414A51), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Serial: ${asset.serialNumber.isNotEmpty ? asset.serialNumber : "N/A"} • Type: ${asset.assetTypeName}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Transfer To Employee Dropdown *
                        DropdownButtonFormField<Employee>(
                          value: selectedTargetEmployee,
                          decoration: InputDecoration(
                            labelText: 'Transfer To Employee *',
                            hintText: 'Select employee from list...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                          ),
                          items: availableEmployees.map((emp) {
                            return DropdownMenuItem<Employee>(
                              value: emp,
                              child: Text(
                                '${emp.fullName} (${emp.employeeId.isNotEmpty ? emp.employeeId : "Emp #${emp.id}"})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedTargetEmployee = val);
                          },
                          validator: (val) {
                            if (val == null) {
                              return 'Please select an employee to transfer asset to';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Transfer Date *
                        TextFormField(
                          controller: transferDateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Transfer Date *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined, size: 18),
                              onPressed: () async {
                                final cur = DateTime.tryParse(transferDateController.text) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: dialogCtx,
                                  initialDate: cur,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    transferDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                  });
                                }
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Transfer date required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Reason / Description *
                        TextFormField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Reason for Transfer / Description *',
                            hintText: 'Enter reason or notes for asset transfer...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please provide a transfer reason or note';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CC70A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final target = selectedTargetEmployee!;
                            await ref.read(assetAssignmentRepositoryProvider).createTransferRequest(
                              AssetTransferRequest(
                                id: 0,
                                assetAssignmentId: asset.id,
                                assetName: asset.assetName,
                                assetTypeName: asset.assetTypeName,
                                serialNumber: asset.serialNumber,
                                fromEmployeeId: asset.employeeId,
                                fromEmployeeName: asset.employeeName,
                                fromEmployeeCode: asset.employeeCode,
                                toEmployeeId: target.id,
                                toEmployeeName: target.fullName,
                                toEmployeeCode: target.employeeId,
                                transferDate: transferDateController.text.trim(),
                                reason: reasonController.text.trim(),
                              ),
                            );
                            ref.invalidate(assetTransferRequestsProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text('Transfer request sent to ${target.fullName}.'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF9CC70A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error transferring asset: $e')),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.swap_horiz_outlined, size: 18),
                  label: const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );

    transferDateController.dispose();
    reasonController.dispose();
  }

  void _showAssetDetailsDialog(AssetAssignment asset) {
    final statusColor = _getStatusColor(asset.status);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_getAssetIcon(asset.assetTypeName), color: const Color(0xFF414A51), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Asset Type: ${asset.assetTypeName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(
                asset.status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow('Assigned To', asset.employeeName.isNotEmpty ? asset.employeeName : 'N/A'),
                if (asset.employeeCode.isNotEmpty)
                  _buildDetailRow('Employee Code', asset.employeeCode),
                _buildDetailRow('Serial Number', asset.serialNumber.isNotEmpty ? asset.serialNumber : 'N/A'),
                _buildDetailRow('Assigned Date', asset.assignedDate.isNotEmpty ? asset.assignedDate : 'N/A'),
                if (asset.description.isNotEmpty)
                  _buildDetailRow('Description / Note', asset.description),
                if (asset.status == 'Maintenance') ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.build_circle_outlined, color: Color(0xFFFF9800), size: 18),
                            SizedBox(width: 6),
                            Text('Maintenance Information', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (asset.maintenanceGivenDate != null && asset.maintenanceGivenDate!.isNotEmpty)
                          _buildDetailRow('Given Date', asset.maintenanceGivenDate!),
                        if (asset.maintenanceReturnDate != null && asset.maintenanceReturnDate!.isNotEmpty)
                          _buildDetailRow('Expected Return', asset.maintenanceReturnDate!),
                        if (asset.maintenanceContact != null && asset.maintenanceContact!.isNotEmpty)
                          _buildDetailRow('Contact Person/Phone', asset.maintenanceContact!),
                        if (asset.maintenanceAddress != null && asset.maintenanceAddress!.isNotEmpty)
                          _buildDetailRow('Service Center Address', asset.maintenanceAddress!),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF414A51),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myAssetsAsync = ref.watch(myAssetAssignmentsProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final searchQ = ref.watch(myAssetSearchQueryProvider);
    final statusFilter = ref.watch(myAssetStatusFilterProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        toolbarHeight: 0,
        bottom: const TabBar(
          labelColor: Color(0xFF9CC70A),
          unselectedLabelColor: Color(0xFF414A51),
          indicatorColor: Color(0xFF9CC70A),
          tabs: [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'My Assets'),
            Tab(icon: Icon(Icons.move_to_inbox_outlined, size: 18), text: 'Transfer Requests'),
          ],
        ),
      ),
      body: TabBarView(children: [
      myAssetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
        error: (err, stack) => Center(child: Text('Error loading assets: $err')),
        data: (assignments) {
          final allEmployees = employeesAsync.asData?.value ?? [];

          // Filter by search query & status
          final filteredAssignments = assignments.where((asset) {
            final matchesStatus = statusFilter == 'All' || asset.status == statusFilter;
            final q = searchQ.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                asset.assetTypeName.toLowerCase().contains(q) ||
                asset.assetName.toLowerCase().contains(q) ||
                asset.serialNumber.toLowerCase().contains(q) ||
                asset.description.toLowerCase().contains(q);
            return matchesStatus && matchesSearch;
          }).toList();

          final totalCount = assignments.length;
          final assignedCount = assignments.where((a) => a.status == 'Assigned').length;
          final maintenanceCount = assignments.where((a) => a.status == 'Maintenance').length;
          final returnedCount = assignments.where((a) => a.status == 'Returned').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Metrics Summary Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMetricCard(
                          title: 'Total Assets',
                          value: '$totalCount',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF414A51),
                          width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
                        ),
                        _buildMetricCard(
                          title: 'Assigned (Active)',
                          value: '$assignedCount',
                          icon: Icons.check_circle_outline,
                          color: const Color(0xFF9CC70A),
                          width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
                        ),
                        _buildMetricCard(
                          title: 'Under Maintenance',
                          value: '$maintenanceCount',
                          icon: Icons.build_circle_outlined,
                          color: const Color(0xFFFF9800),
                          width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
                        ),
                        _buildMetricCard(
                          title: 'Returned',
                          value: '$returnedCount',
                          icon: Icons.history,
                          color: const Color(0xFF757575),
                          width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Search & Filter Toolbar
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) {
                                  ref.read(myAssetSearchQueryProvider.notifier).state = val;
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search by asset name, type, or serial number...',
                                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF414A51)),
                                  suffixIcon: searchQ.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            ref.read(myAssetSearchQueryProvider.notifier).state = '';
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF9CC70A), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Assigned', 'Maintenance', 'Returned'].map((status) {
                              final isSelected = statusFilter == status;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF9CC70A),
                                  backgroundColor: Colors.grey[100],
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      ref.read(myAssetStatusFilterProvider.notifier).state = status;
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Asset Cards Grid / List
                if (filteredAssignments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_other_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          searchQ.isNotEmpty || statusFilter != 'All'
                              ? 'No assets match your search/filter.'
                              : 'No assets assigned to you yet.',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          searchQ.isNotEmpty || statusFilter != 'All'
                              ? 'Try clearing filters to view all assigned assets.'
                              : 'When an asset is assigned to you in Asset Management, it will appear here.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900
                          ? 3
                          : (constraints.maxWidth > 600 ? 2 : 1);

                      if (crossAxisCount == 1) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredAssignments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildAssetCard(filteredAssignments[index], allEmployees);
                          },
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.12,
                        ),
                        itemCount: filteredAssignments.length,
                        itemBuilder: (context, index) {
                          return _buildAssetCard(filteredAssignments[index], allEmployees);
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
      _buildIncomingRequests(),
      ]),
      ),
    );
  }

  Widget _buildIncomingRequests() {
    final requestsAsync = ref.watch(myIncomingAssetTransferRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
      error: (error, _) => Center(child: Text('Error loading transfer requests: $error')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.move_to_inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text('No transfer requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51))),
                const SizedBox(height: 6),
                Text('Incoming asset transfer requests will appear here.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _buildTransferRequestCard(requests[index]),
        );
      },
    );
  }

  Widget _buildTransferRequestCard(AssetTransferRequest request) {
    final pending = request.status == 'Pending';
    final statusColor = request.status == 'Approved'
        ? const Color(0xFF9CC70A)
        : request.status == 'Rejected' ? Colors.red : const Color(0xFFFF9800);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF9CC70A).withOpacity(.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(_getAssetIcon(request.assetTypeName), color: const Color(0xFF9CC70A)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.assetName.isEmpty ? request.assetTypeName : request.assetName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text('${request.assetTypeName} • ${request.serialNumber.isEmpty ? "N/A" : request.serialNumber}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
              child: Text(request.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          Text('From: ${request.fromEmployeeName}${request.fromEmployeeCode.isEmpty ? "" : " (${request.fromEmployeeCode})"}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text('Transfer date: ${request.transferDate}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          const SizedBox(height: 8),
          Text(request.reason, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          if (pending) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                onPressed: () => _respondToTransfer(request, false),
                icon: const Icon(Icons.close, size: 17),
                label: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9CC70A), foregroundColor: Colors.white),
                onPressed: () => _respondToTransfer(request, true),
                icon: const Icon(Icons.check, size: 17),
                label: const Text('Accept'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _respondToTransfer(AssetTransferRequest request, bool approve) async {
    try {
      await ref.read(assetAssignmentRepositoryProvider).respondToTransferRequest(request, approve: approve);
      ref.invalidate(assetTransferRequestsProvider);
      ref.invalidate(assetAssignmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Asset transfer accepted.' : 'Asset transfer rejected.'),
        backgroundColor: approve ? const Color(0xFF9CC70A) : const Color(0xFF414A51),
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update request: $error')));
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard(AssetAssignment asset, List<Employee> employees) {
    final statusColor = _getStatusColor(asset.status);
    final iconData = _getAssetIcon(asset.assetTypeName);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Icon + Asset Name + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: const Color(0xFF9CC70A), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF212121)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        asset.assetTypeName,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    asset.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Key Info: Serial Number & Assigned Date
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Serial No: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Expanded(
                        child: Text(
                          asset.serialNumber.isNotEmpty ? asset.serialNumber : 'N/A',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Assigned Date: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Expanded(
                        child: Text(
                          asset.assignedDate.isNotEmpty ? asset.assignedDate : 'N/A',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (asset.status == 'Maintenance' && asset.maintenanceReturnDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFFFF9800)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Maintenance return date: ${asset.maintenanceReturnDate}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Action Buttons Row: Maintenance | Transfer | Details
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0xFFFFCC80)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    ),
                    onPressed: () => _showMaintenanceDialog(asset),
                    icon: const Icon(Icons.build_outlined, size: 14),
                    label: const Text('Maintenance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9CC70A),
                      side: const BorderSide(color: Color(0xFFC5E1A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    ),
                    onPressed: () => _showTransferDialog(asset, employees),
                    icon: const Icon(Icons.swap_horiz_outlined, size: 14),
                    label: const Text('Transfer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'View Details',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAssetDetailsDialog(asset),
                  icon: const Icon(Icons.info_outline, size: 16, color: Color(0xFF414A51)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
