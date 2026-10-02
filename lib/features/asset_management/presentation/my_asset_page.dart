import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/asset_assignment.dart';
import '../domain/asset_transfer_request.dart';
import '../domain/asset_return_request.dart';
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
                            ref.invalidate(myAllAssetTransferRequestsProvider);
                            ref.invalidate(myIncomingAssetTransferRequestsProvider);
                            ref.invalidate(myOutgoingAssetTransferRequestsProvider);

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

  Future<void> _showReturnDialog(AssetAssignment asset) async {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

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
                  Icon(Icons.assignment_return_outlined, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 10),
                  Text('Return Asset Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (asset.serialNumber.isNotEmpty)
                              Text('Serial No: ${asset.serialNumber}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Return Reason / Condition Notes *',
                          hintText: 'Enter reason for returning asset (e.g. project completed, damaged, upgrading)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter return reason';
                          }
                          return null;
                        },
                      ),
                    ],
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
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            final currentEmp = ref.read(myAssetSelectedEmployeeProvider) ?? ref.read(currentEmployeeProvider);
                            final empId = currentEmp?.id ?? asset.employeeId;
                            final empName = (currentEmp != null && currentEmp.fullName.trim().isNotEmpty) ? currentEmp.fullName : asset.employeeName;
                            final empCode = (currentEmp != null && currentEmp.employeeId.trim().isNotEmpty) ? currentEmp.employeeId : asset.employeeCode;

                            final returnReq = AssetReturnRequest(
                              id: 0,
                              assetAssignmentId: asset.id,
                              assetName: asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                              assetTypeName: asset.assetTypeName,
                              serialNumber: asset.serialNumber,
                              employeeId: empId,
                              employeeName: empName,
                              employeeCode: empCode,
                              requestDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                              reason: reasonController.text.trim(),
                              status: 'Pending',
                            );

                            await ref.read(assetAssignmentRepositoryProvider).createReturnRequest(returnReq);
                            ref.refresh(assetReturnRequestsProvider);
                            ref.refresh(myAssetReturnRequestsProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text('Return request submitted. Waiting for admin approval.'),
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
                                SnackBar(content: Text('Error submitting return request: $e')),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Submit Return Request'),
                ),
              ],
            );
          },
        );
      },
    );

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
      body: RefreshIndicator(
        color: const Color(0xFF9CC70A),
        onRefresh: () async {
          ref.invalidate(myAssetAssignmentsProvider);
          ref.invalidate(employeesProvider);
          ref.invalidate(assetAssignmentsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: TabBarView(children: [
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
        _buildTransferRequestsTab(),
        ]),
      ),
      ),
    );

  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildTransferRequestsTab() {
    final allRequestsAsync = ref.watch(myAllAssetTransferRequestsProvider);
    final transferFilter = ref.watch(myAssetTransferFilterProvider);
    final overrideEmp = ref.watch(myAssetSelectedEmployeeProvider);
    final currentEmp = overrideEmp ?? ref.watch(currentEmployeeProvider);

    return allRequestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF9CC70A))),
      error: (error, _) => Center(child: Text('Error loading transfer requests: $error')),
      data: (requests) {
        final code = currentEmp?.employeeId.trim().toLowerCase() ?? '';
        final name = currentEmp?.fullName.trim().toLowerCase() ?? '';
        final empId = currentEmp?.id ?? 0;

        bool isOutgoingReq(AssetTransferRequest r) {
          return (empId > 0 && r.fromEmployeeId == empId) ||
              (code.isNotEmpty && r.fromEmployeeCode.trim().toLowerCase() == code) ||
              (name.isNotEmpty && r.fromEmployeeName.trim().toLowerCase() == name);
        }

        bool isIncomingReq(AssetTransferRequest r) {
          return (empId > 0 && r.toEmployeeId == empId) ||
              (code.isNotEmpty && r.toEmployeeCode.trim().toLowerCase() == code) ||
              (name.isNotEmpty && r.toEmployeeName.trim().toLowerCase() == name);
        }

        final incomingRequests = requests.where(isIncomingReq).toList();
        final outgoingRequests = requests.where(isOutgoingReq).toList();

        final pendingIncomingCount = incomingRequests.where((r) => r.status == 'Pending').length;
        final pendingOutgoingCount = outgoingRequests.where((r) => r.status == 'Pending').length;

        List<AssetTransferRequest> displayedRequests = [];
        if (transferFilter == 'Received') {
          displayedRequests = incomingRequests;
        } else if (transferFilter == 'Sent') {
          displayedRequests = outgoingRequests;
        } else {
          displayedRequests = requests;
        }

        final employees = ref.watch(employeesProvider).asData?.value ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Toolbar
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20, color: Color(0xFF414A51)),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF414A51)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTransferFilterChip(
                                label: 'All Transfers',
                                count: requests.length,
                                isSelected: transferFilter == 'All',
                                onSelected: () => ref.read(myAssetTransferFilterProvider.notifier).state = 'All',
                              ),
                              const SizedBox(width: 8),
                              _buildTransferFilterChip(
                                label: 'Received (Incoming)',
                                count: incomingRequests.length,
                                badgePending: pendingIncomingCount > 0 ? pendingIncomingCount : null,
                                isSelected: transferFilter == 'Received',
                                onSelected: () => ref.read(myAssetTransferFilterProvider.notifier).state = 'Received',
                              ),
                              const SizedBox(width: 8),
                              _buildTransferFilterChip(
                                label: 'Sent (Outgoing)',
                                count: outgoingRequests.length,
                                badgePending: pendingOutgoingCount > 0 ? pendingOutgoingCount : null,
                                isSelected: transferFilter == 'Sent',
                                onSelected: () => ref.read(myAssetTransferFilterProvider.notifier).state = 'Sent',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (displayedRequests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        transferFilter == 'Received'
                            ? 'No incoming transfer requests.'
                            : transferFilter == 'Sent'
                                ? 'No outgoing transfer requests.'
                                : 'No asset transfer requests found.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF414A51)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        transferFilter == 'Received'
                            ? 'When another employee initiates a transfer to you, it will appear here for your acceptance.'
                            : transferFilter == 'Sent'
                                ? 'When you transfer an assigned asset to another employee, track its acceptance status here.'
                                : 'Incoming and outgoing asset transfer requests will appear here.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final req = displayedRequests[index];
                    final isOutgoing = isOutgoingReq(req);
                    final isIncoming = isIncomingReq(req);
                    return _buildTransferRequestCard(
                      req,
                      isOutgoing: isOutgoing,
                      isIncoming: isIncoming,
                      employees: employees,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransferFilterChip({
    required String label,
    required int count,
    int? badgePending,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ($count)'),
          if (badgePending != null && badgePending > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgePending pending',
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF9800) : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF9CC70A),
      backgroundColor: Colors.grey[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTransferRequestCard(
    AssetTransferRequest request, {
    required bool isOutgoing,
    required bool isIncoming,
    required List<Employee> employees,
  }) {
    final pending = request.status == 'Pending';
    final approved = request.status == 'Approved';
    final rejected = request.status == 'Rejected';
    final cancelled = request.status == 'Cancelled';

    final statusColor = approved
        ? const Color(0xFF9CC70A)
        : rejected
            ? const Color(0xFFDC2626)
            : cancelled
                ? const Color(0xFF64748B)
                : const Color(0xFFFF9800);

    final statusLabel = approved
        ? 'Accepted'
        : rejected
            ? 'Declined'
            : cancelled
                ? 'Cancelled'
                : 'Pending';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: pending ? const Color(0xFFFFE082) : Colors.grey[200]!,
          width: pending ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon, Asset Name, Direction Badge & Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getAssetIcon(request.assetTypeName), color: const Color(0xFF414A51), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.assetName.isEmpty ? request.assetTypeName : request.assetName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${request.assetTypeName} • Serial: ${request.serialNumber.isEmpty ? "N/A" : request.serialNumber}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Direction Badge (Sent / Received)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? const Color(0xFF414A51).withOpacity(0.08)
                        : const Color(0xFF9CC70A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOutgoing
                          ? const Color(0xFF414A51).withOpacity(0.2)
                          : const Color(0xFF9CC70A).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOutgoing ? Icons.upload_outlined : Icons.download_outlined,
                        size: 13,
                        color: isOutgoing ? const Color(0xFF414A51) : const Color(0xFF6B8B00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOutgoing ? 'Sent' : 'Received',
                        style: TextStyle(
                          color: isOutgoing ? const Color(0xFF414A51) : const Color(0xFF6B8B00),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Transfer Details Grid (From, To, Date, Reason)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('From (Sender)', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              '${request.fromEmployeeName}${request.fromEmployeeCode.isNotEmpty ? " (${request.fromEmployeeCode})" : ""}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To (Recipient)', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              '${request.toEmployeeName}${request.toEmployeeCode.isNotEmpty ? " (${request.toEmployeeCode})" : ""}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF212121)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transfer Date', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              request.transferDate.isNotEmpty ? request.transferDate : 'N/A',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (request.createdAt != null && request.createdAt!.isNotEmpty)
                        Expanded(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Requested On', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimestamp(request.createdAt),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (request.reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 12),
                    Text('Reason / Description:', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      request.reason,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF333333)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Status Description Notice / Action Footer
            if (isOutgoing) ...[
              if (pending) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_outlined, color: Color(0xFFFF9800), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Waiting for ${request.toEmployeeName} to accept this transfer request. The asset remains under your assignment until accepted.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _confirmCancelTransferRequest(request),
                      icon: const Icon(Icons.cancel_outlined, size: 17),
                      label: const Text('Cancel Request'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF414A51),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showEditTransferDialog(request, employees),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: const Text('Edit Request'),
                    ),
                  ],
                ),
              ] else if (approved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF9CC70A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Accepted by ${request.toEmployeeName}${request.toEmployeeCode.isNotEmpty ? " (${request.toEmployeeCode})" : ""}${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}. The asset has been transferred.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF33691E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (rejected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Declined by ${request.toEmployeeName}${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}. The asset remains assigned to you.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else if (cancelled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block_outlined, color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cancelled this transfer request${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}. The asset remains assigned to you.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (isIncoming) ...[
              if (pending) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${request.fromEmployeeName} has initiated a transfer of this asset to you. Please accept to add it to your assigned assets, or reject.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _respondToTransfer(request, false),
                      icon: const Icon(Icons.close, size: 17),
                      label: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9CC70A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _respondToTransfer(request, true),
                      icon: const Icon(Icons.check, size: 17),
                      label: const Text('Accept Transfer'),
                    ),
                  ],
                ),
              ] else if (approved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF9CC70A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You accepted this asset transfer${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}. It is now in your active assets list.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF33691E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (rejected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You declined this asset transfer request${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else if (cancelled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block_outlined, color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This transfer request was cancelled by ${request.fromEmployeeName}${request.respondedAt != null ? " on ${_formatTimestamp(request.respondedAt)}" : ""}.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Edit Transfer Request Dialog ─────────────────────────────────────────
  Future<void> _showEditTransferDialog(
    AssetTransferRequest request,
    List<Employee> employees,
  ) async {
    final formKey = GlobalKey<FormState>();
    final availableEmployees = employees.where((e) => e.id != request.fromEmployeeId).toList();
    final matchingEmployees = availableEmployees.where(
      (e) => (request.toEmployeeId > 0 && e.id == request.toEmployeeId) ||
          (request.toEmployeeCode.isNotEmpty && e.employeeId.toLowerCase() == request.toEmployeeCode.toLowerCase()),
    ).toList();
    Employee? selectedTargetEmployee = matchingEmployees.isNotEmpty
        ? matchingEmployees.first
        : (availableEmployees.isNotEmpty ? availableEmployees.first : null);

    final transferDateController = TextEditingController(text: request.transferDate);
    final reasonController = TextEditingController(text: request.reason);
    bool isSubmitting = false;

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
                  Icon(Icons.edit_note_outlined, color: Color(0xFF9CC70A), size: 24),
                  SizedBox(width: 10),
                  Text('Edit Transfer Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                              Icon(_getAssetIcon(request.assetTypeName), color: const Color(0xFF414A51), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.assetName.isNotEmpty ? request.assetName : request.assetTypeName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Serial: ${request.serialNumber.isNotEmpty ? request.serialNumber : "N/A"} • Type: ${request.assetTypeName}',
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
                            final updated = request.copyWith(
                              toEmployeeId: target.id,
                              toEmployeeName: target.fullName,
                              toEmployeeCode: target.employeeId,
                              transferDate: transferDateController.text.trim(),
                              reason: reasonController.text.trim(),
                            );
                            await ref.read(assetAssignmentRepositoryProvider).updateTransferRequest(updated);
                            ref.invalidate(assetTransferRequestsProvider);
                            ref.invalidate(myAllAssetTransferRequestsProvider);
                            ref.invalidate(myIncomingAssetTransferRequestsProvider);
                            ref.invalidate(myOutgoingAssetTransferRequestsProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text('Transfer request updated successfully.'),
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
                                SnackBar(content: Text('Error updating transfer request: $e')),
                              );
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Changes'),
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

  // ── Cancel Transfer Request Dialog ───────────────────────────────────────
  Future<void> _confirmCancelTransferRequest(AssetTransferRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Cancel Transfer Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel the transfer request for "${request.assetName.isNotEmpty ? request.assetName : request.assetTypeName}" to ${request.toEmployeeName}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(assetAssignmentRepositoryProvider).cancelTransferRequest(request.id);
        ref.invalidate(assetTransferRequestsProvider);
        ref.invalidate(myAllAssetTransferRequestsProvider);
        ref.invalidate(myIncomingAssetTransferRequestsProvider);
        ref.invalidate(myOutgoingAssetTransferRequestsProvider);
        ref.invalidate(assetAssignmentsProvider);
        ref.invalidate(myAssetAssignmentsProvider);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transfer request cancelled successfully.'),
            backgroundColor: const Color(0xFF414A51),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling transfer request: $e')),
        );
      }
    }
  }

  Future<void> _respondToTransfer(AssetTransferRequest request, bool approve) async {
    try {
      await ref.read(assetAssignmentRepositoryProvider).respondToTransferRequest(request, approve: approve);
      ref.invalidate(assetTransferRequestsProvider);
      ref.invalidate(myAllAssetTransferRequestsProvider);
      ref.invalidate(myIncomingAssetTransferRequestsProvider);
      ref.invalidate(myOutgoingAssetTransferRequestsProvider);
      ref.invalidate(assetAssignmentsProvider);
      ref.invalidate(myAssetAssignmentsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Asset transfer accepted successfully.' : 'Asset transfer declined.'),
        backgroundColor: approve ? const Color(0xFF9CC70A) : const Color(0xFF414A51),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final returnRequestsAsync = ref.watch(assetReturnRequestsProvider);
    final returnRequests = returnRequestsAsync.asData?.value ?? [];
    final pendingReturnReq = returnRequests.where(
      (r) => r.assetAssignmentId == asset.id && r.status == 'Pending',
    ).firstOrNull;
    final isReturned = asset.status == 'Returned';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Asset Icon, Name/Type, Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9CC70A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getAssetIcon(asset.assetTypeName),
                    color: const Color(0xFF414A51),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.assetName.isNotEmpty ? asset.assetName : asset.assetTypeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        asset.assetTypeName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

            if (pendingReturnReq != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.hourglass_top_outlined, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Return Request Pending Approval',
                        style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

            // Action Buttons Row: Maintenance | Transfer | Return | Details
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: const BorderSide(color: Color(0xFFFFCC80)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    ),
                    onPressed: () => _showMaintenanceDialog(asset),
                    icon: const Icon(Icons.build_outlined, size: 13),
                    label: const Text('Maintenance', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9CC70A),
                      side: const BorderSide(color: Color(0xFFC5E1A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    ),
                    onPressed: () => _showTransferDialog(asset, employees),
                    icon: const Icon(Icons.swap_horiz_outlined, size: 13),
                    label: const Text('Transfer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isReturned
                          ? Colors.grey
                          : const Color(0xFFDC2626),
                      side: BorderSide(
                        color: isReturned
                            ? Colors.grey.shade300
                            : const Color(0xFFFCA5A5),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      backgroundColor: pendingReturnReq != null ? const Color(0xFFFEF2F2) : null,
                    ),
                    onPressed: isReturned
                        ? null
                        : () {
                            if (pendingReturnReq != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('A return request for this asset is already pending admin approval.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                              return;
                            }
                            _showReturnDialog(asset);
                          },
                    icon: Icon(
                      pendingReturnReq != null ? Icons.hourglass_top_outlined : Icons.assignment_return_outlined,
                      size: 13,
                    ),
                    label: Text(
                      isReturned
                          ? 'Returned'
                          : (pendingReturnReq != null ? 'Pending' : 'Return'),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'View Details',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showAssetDetailsDialog(asset),
                  icon: const Icon(Icons.info_outline, size: 15, color: Color(0xFF414A51)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
