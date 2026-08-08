import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../asset_settings/domain/asset_type.dart';
import '../../asset_settings/providers/asset_settings_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/asset_assignment.dart';
import '../providers/asset_management_providers.dart';
import 'widgets/asset_column_selection_dialog.dart';
import 'widgets/custom_date_range_picker_dialog.dart';

class AssetManagementPage extends ConsumerStatefulWidget {
  const AssetManagementPage({super.key});

  @override
  ConsumerState<AssetManagementPage> createState() => _AssetManagementPageState();
}

class AssetItemFormData {
  AssetType? selectedAssetType;
  final assetNameController = TextEditingController();
  final serialNumberController = TextEditingController();
  final descController = TextEditingController();
  String selectedStatus = 'Assigned';
  final maintAddressController = TextEditingController();
  final maintContactController = TextEditingController();
  final maintGivenDateController = TextEditingController();
  final maintReturnDateController = TextEditingController();

  AssetItemFormData({
    this.selectedAssetType,
    String? assetName,
    String? serialNumber,
    String? description,
    String? status,
    String? maintAddress,
    String? maintContact,
    String? maintGivenDate,
    String? maintReturnDate,
  }) {
    if (assetName != null) assetNameController.text = assetName;
    if (serialNumber != null) serialNumberController.text = serialNumber;
    if (description != null) descController.text = description;
    if (status != null) selectedStatus = status;
    if (maintAddress != null) maintAddressController.text = maintAddress;
    if (maintContact != null) maintContactController.text = maintContact;
    maintGivenDateController.text = maintGivenDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    maintReturnDateController.text = maintReturnDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 7)));
  }

  void dispose() {
    assetNameController.dispose();
    serialNumberController.dispose();
    descController.dispose();
    maintAddressController.dispose();
    maintContactController.dispose();
    maintGivenDateController.dispose();
    maintReturnDateController.dispose();
  }
}

class _AssetManagementPageState extends ConsumerState<AssetManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Employee?> _showEmployeePickerDialog(
    BuildContext context,
    List<Employee> employees,
    Employee? currentSelected,
  ) async {
    return showDialog<Employee>(
      context: context,
      builder: (pickerContext) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = employees.where((emp) {
              if (search.trim().isEmpty) return true;
              final q = search.toLowerCase().trim();
              final matchName = emp.fullName.toLowerCase().contains(q);
              final matchCode = emp.employeeId.toLowerCase().contains(q);
              final matchEmail = emp.emailAddress.toLowerCase().contains(q);
              return matchName || matchCode || matchEmail;
            }).toList();

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.person_search_outlined, color: AppColors.active),
                  SizedBox(width: 8),
                  Text('Select Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 460,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search employee by name, ID code, email...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setPickerState(() => search = ''),
                              )
                            : null,
                      ),
                      onChanged: (val) => setPickerState(() => search = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No employees found', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final emp = filtered[index];
                                final isSelected = currentSelected?.id == emp.id;
                                final codeStr = emp.employeeId.isNotEmpty ? ' (${emp.employeeId})' : '';

                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: AppColors.active.withValues(alpha: 0.1),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                    ),
                                  ),
                                  title: Text(
                                    '${emp.fullName}$codeStr',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: emp.designation.isNotEmpty ? Text(emp.designation, style: const TextStyle(fontSize: 11)) : null,
                                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.active, size: 18) : null,
                                  onTap: () => Navigator.pop(pickerContext, emp),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(pickerContext, null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignAssetDialog({
    AssetAssignment? assignmentToEdit,
    required List<Employee> employees,
    required List<AssetType> assetTypes,
  }) {
    final isEditing = assignmentToEdit != null;

    Employee? selectedEmployee;
    if (isEditing) {
      final matches = employees.where((e) => e.id == assignmentToEdit.employeeId).toList();
      if (matches.isNotEmpty) {
        selectedEmployee = matches.first;
      }
    }

    final dateController = TextEditingController(
      text: isEditing
          ? assignmentToEdit.assignedDate
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    final List<AssetItemFormData> assetItems = [];
    if (isEditing) {
      AssetType? editingAssetType;
      final matches = assetTypes.where((a) => a.id == assignmentToEdit.assetTypeId).toList();
      if (matches.isNotEmpty) editingAssetType = matches.first;

      assetItems.add(AssetItemFormData(
        selectedAssetType: editingAssetType,
        assetName: assignmentToEdit.assetName,
        serialNumber: assignmentToEdit.serialNumber,
        description: assignmentToEdit.description,
        status: assignmentToEdit.status,
        maintAddress: assignmentToEdit.maintenanceAddress,
        maintContact: assignmentToEdit.maintenanceContact,
        maintGivenDate: assignmentToEdit.maintenanceGivenDate,
        maintReturnDate: assignmentToEdit.maintenanceReturnDate,
      ));
    } else {
      assetItems.add(AssetItemFormData());
    }

    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Update Asset Assignment' : 'Assign Assets to Employee',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Select Employee (Searchable)
                        FormField<Employee>(
                          initialValue: selectedEmployee,
                          validator: (val) {
                            if (selectedEmployee == null) return 'Please select an employee';
                            return null;
                          },
                          builder: (fieldState) {
                            final codeStr = selectedEmployee?.employeeId.isNotEmpty == true
                                ? ' (${selectedEmployee!.employeeId})'
                                : '';
                            final displayText = selectedEmployee != null
                                ? '${selectedEmployee!.fullName}$codeStr'
                                : 'Select Employee *';

                            return InkWell(
                              onTap: () async {
                                final picked = await _showEmployeePickerDialog(context, employees, selectedEmployee);
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedEmployee = picked;
                                  });
                                  fieldState.didChange(picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Select Employee *',
                                  border: const OutlineInputBorder(),
                                  errorText: fieldState.errorText,
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                  prefixIcon: const Icon(Icons.person_search_outlined),
                                ),
                                child: Text(
                                  displayText,
                                  style: TextStyle(
                                    color: selectedEmployee != null ? AppColors.textPrimary : Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Assignment Date Picker Field
                        TextFormField(
                          controller: dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Assigned Date *',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final now = DateTime.now();
                                final initial = DateTime.tryParse(dateController.text) ?? now;
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                }
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Date is required';
                            return null;
                          },
                          onTap: () async {
                            final now = DateTime.now();
                            final initial = DateTime.tryParse(dateController.text) ?? now;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Header for Assets List
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Assigned Assets',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.active.withValues(alpha: 0.1),
                                foregroundColor: AppColors.active,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Another Asset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setDialogState(() {
                                  assetItems.add(AssetItemFormData());
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Asset Items List
                        ...assetItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.active.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.devices, size: 16, color: AppColors.active),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Asset #${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    const Spacer(),
                                    if (assetItems.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        tooltip: 'Remove Asset',
                                        onPressed: () {
                                          setDialogState(() {
                                            final removed = assetItems.removeAt(index);
                                            removed.dispose();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Select Asset Type
                                DropdownButtonFormField<AssetType>(
                                  initialValue: item.selectedAssetType,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Asset Type *',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: assetTypes.map((type) {
                                    return DropdownMenuItem<AssetType>(
                                      value: type,
                                      child: Text('${type.name} (${type.category})'),
                                    );
                                  }).toList(),
                                  validator: (val) {
                                    if (val == null) return 'Please select an asset type';
                                    return null;
                                  },
                                  onChanged: (val) {
                                    setDialogState(() => item.selectedAssetType = val);
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Asset Name
                                TextFormField(
                                  controller: item.assetNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Asset Name *',
                                    hintText: 'Enter asset name (e.g. MacBook Pro M2, Dell Latitude 5420)...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter asset name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Asset Serial Number
                                TextFormField(
                                  controller: item.serialNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Asset Serial Number',
                                    hintText: 'Enter serial number / tag ID...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Description / Reason
                                TextFormField(
                                  controller: item.descController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Reason for Assignment / Description *',
                                    hintText: 'Enter reason or description...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter a description or reason';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Status Dropdown
                                DropdownButtonFormField<String>(
                                  initialValue: item.selectedStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Assignment Status',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                                    DropdownMenuItem(value: 'Returned', child: Text('Returned')),
                                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => item.selectedStatus = val);
                                    }
                                  },
                                ),

                                // Maintenance details if Maintenance status selected
                                if (item.selectedStatus == 'Maintenance') ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.build_circle_outlined, size: 16, color: Colors.orange),
                                            SizedBox(width: 6),
                                            Text(
                                              'Maintenance Details',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: item.maintAddressController,
                                          maxLines: 2,
                                          decoration: const InputDecoration(
                                            labelText: 'Maintenance Place Address *',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          validator: (val) {
                                            if (item.selectedStatus == 'Maintenance' && (val == null || val.trim().isEmpty)) {
                                              return 'Please enter maintenance address';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: item.maintContactController,
                                          decoration: const InputDecoration(
                                            labelText: 'Contact Number *',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          validator: (val) {
                                            if (item.selectedStatus == 'Maintenance' && (val == null || val.trim().isEmpty)) {
                                              return 'Please enter contact number';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: item.maintGivenDateController,
                                                readOnly: true,
                                                decoration: InputDecoration(
                                                  labelText: 'Given Date *',
                                                  border: const OutlineInputBorder(),
                                                  isDense: true,
                                                  suffixIcon: IconButton(
                                                    icon: const Icon(Icons.calendar_today, size: 14),
                                                    onPressed: () async {
                                                      final now = DateTime.now();
                                                      final initial = DateTime.tryParse(item.maintGivenDateController.text) ?? now;
                                                      final picked = await showDatePicker(
                                                        context: context,
                                                        initialDate: initial,
                                                        firstDate: DateTime(2020),
                                                        lastDate: DateTime(2035),
                                                      );
                                                      if (picked != null) {
                                                        item.maintGivenDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                validator: (val) {
                                                  if (item.selectedStatus == 'Maintenance' && (val == null || val.trim().isEmpty)) {
                                                    return 'Given date required';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextFormField(
                                                controller: item.maintReturnDateController,
                                                readOnly: true,
                                                decoration: InputDecoration(
                                                  labelText: 'Return Date *',
                                                  border: const OutlineInputBorder(),
                                                  isDense: true,
                                                  suffixIcon: IconButton(
                                                    icon: const Icon(Icons.calendar_today, size: 14),
                                                    onPressed: () async {
                                                      final now = DateTime.now();
                                                      final initial = DateTime.tryParse(item.maintReturnDateController.text) ?? now;
                                                      final picked = await showDatePicker(
                                                        context: context,
                                                        initialDate: initial,
                                                        firstDate: DateTime(2020),
                                                        lastDate: DateTime(2035),
                                                      );
                                                      if (picked != null) {
                                                        item.maintReturnDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                validator: (val) {
                                                  if (item.selectedStatus == 'Maintenance' && (val == null || val.trim().isEmpty)) {
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
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (final item in assetItems) {
                      item.dispose();
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    isEditing
                        ? 'Update Record'
                        : 'Assign ${assetItems.length} Asset${assetItems.length > 1 ? "s" : ""}',
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext);

                    final repo = ref.read(assetAssignmentRepositoryProvider);
                    if (isEditing) {
                      final item = assetItems.first;
                      final isMaint = item.selectedStatus == 'Maintenance';
                      final updated = assignmentToEdit.copyWith(
                        employeeId: selectedEmployee!.id,
                        employeeName: selectedEmployee!.fullName,
                        employeeCode: selectedEmployee!.employeeId,
                        assetTypeId: item.selectedAssetType!.id,
                        assetTypeName: item.selectedAssetType!.name,
                        assetName: item.assetNameController.text.trim(),
                        serialNumber: item.serialNumberController.text.trim(),
                        assignedDate: dateController.text.trim(),
                        description: item.descController.text.trim(),
                        status: item.selectedStatus,
                        maintenanceAddress: isMaint ? item.maintAddressController.text.trim() : null,
                        maintenanceContact: isMaint ? item.maintContactController.text.trim() : null,
                        maintenanceGivenDate: isMaint ? item.maintGivenDateController.text.trim() : null,
                        maintenanceReturnDate: isMaint ? item.maintReturnDateController.text.trim() : null,
                      );
                      await repo.updateAssignment(updated);

                      if (assetItems.length > 1) {
                        final extraAssignments = assetItems.sublist(1).map((extraItem) {
                          final extraIsMaint = extraItem.selectedStatus == 'Maintenance';
                          return AssetAssignment(
                            id: 0,
                            employeeId: selectedEmployee!.id,
                            employeeName: selectedEmployee!.fullName,
                            employeeCode: selectedEmployee!.employeeId,
                            assetTypeId: extraItem.selectedAssetType!.id,
                            assetTypeName: extraItem.selectedAssetType!.name,
                            assetName: extraItem.assetNameController.text.trim(),
                            serialNumber: extraItem.serialNumberController.text.trim(),
                            assignedDate: dateController.text.trim(),
                            description: extraItem.descController.text.trim(),
                            status: extraItem.selectedStatus,
                            maintenanceAddress: extraIsMaint ? extraItem.maintAddressController.text.trim() : null,
                            maintenanceContact: extraIsMaint ? extraItem.maintContactController.text.trim() : null,
                            maintenanceGivenDate: extraIsMaint ? extraItem.maintGivenDateController.text.trim() : null,
                            maintenanceReturnDate: extraIsMaint ? extraItem.maintReturnDateController.text.trim() : null,
                          );
                        }).toList();
                        await repo.addAssignments(extraAssignments);
                      }
                    } else {
                      final newAssignments = assetItems.map((item) {
                        final isMaint = item.selectedStatus == 'Maintenance';
                        return AssetAssignment(
                          id: 0,
                          employeeId: selectedEmployee!.id,
                          employeeName: selectedEmployee!.fullName,
                          employeeCode: selectedEmployee!.employeeId,
                          assetTypeId: item.selectedAssetType!.id,
                          assetTypeName: item.selectedAssetType!.name,
                          assetName: item.assetNameController.text.trim(),
                          serialNumber: item.serialNumberController.text.trim(),
                          assignedDate: dateController.text.trim(),
                          description: item.descController.text.trim(),
                          status: item.selectedStatus,
                          maintenanceAddress: isMaint ? item.maintAddressController.text.trim() : null,
                          maintenanceContact: isMaint ? item.maintContactController.text.trim() : null,
                          maintenanceGivenDate: isMaint ? item.maintGivenDateController.text.trim() : null,
                          maintenanceReturnDate: isMaint ? item.maintReturnDateController.text.trim() : null,
                        );
                      }).toList();
                      await repo.addAssignments(newAssignments);
                    }

                    for (final item in assetItems) {
                      item.dispose();
                    }
                    ref.invalidate(assetAssignmentsProvider);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showViewAssignmentDialog(AssetAssignment record) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isMaint = record.status == 'Maintenance';
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.active),
              const SizedBox(width: 8),
              const Text(
                'Asset Assignment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Employee Name:', record.employeeName + (record.employeeCode.isNotEmpty ? ' (${record.employeeCode})' : '')),
                  const SizedBox(height: 10),
                  _buildDetailRow('Asset Name:', record.assetName.isNotEmpty ? record.assetName : 'N/A'),
                  const SizedBox(height: 10),
                  _buildDetailRow('Asset Type:', record.assetTypeName),
                  const SizedBox(height: 10),
                  _buildDetailRow('Serial Number:', record.serialNumber.isNotEmpty ? record.serialNumber : 'N/A'),
                  const SizedBox(height: 10),
                  _buildDetailRow('Assigned Date:', record.assignedDate),
                  const SizedBox(height: 10),
                  _buildDetailRow('Status:', record.status),
                  const SizedBox(height: 10),
                  _buildDetailRow('Reason / Description:', record.description),
                  if (isMaint || (record.maintenanceAddress?.isNotEmpty ?? false)) ...[
                    const Divider(height: 24),
                    const Text(
                      'Maintenance Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
                    ),
                    const SizedBox(height: 10),
                    _buildDetailRow('Place Address:', record.maintenanceAddress ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Contact Number:', record.maintenanceContact ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Given Date:', record.maintenanceGivenDate ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow('Expected Return Date:', record.maintenanceReturnDate ?? 'N/A'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAssignment(AssetAssignment assignment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Assignment Record'),
          content: Text(
            'Are you sure you want to remove the assignment of "${assignment.assetTypeName}" to "${assignment.employeeName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await ref.read(assetAssignmentRepositoryProvider).deleteAssignment(assignment.id);
                ref.invalidate(assetAssignmentsProvider);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(assetAssignmentsProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final assetTypesAsync = ref.watch(assetTypesProvider);

    final searchQuery = ref.watch(assignmentSearchQueryProvider);
    final empFilter = ref.watch(assignmentEmployeeFilterProvider);
    final assetTypeFilter = ref.watch(assignmentAssetTypeFilterProvider);
    final dateRangeFilter = ref.watch(assignmentDateRangeFilterProvider);
    final statusFilter = ref.watch(assignmentStatusFilterProvider);
    final visibleColumns = ref.watch(assetVisibleColumnsProvider);

    final employees = employeesAsync.asData?.value ?? [];
    final assetTypes = assetTypesAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                const Icon(Icons.devices_other_outlined, size: 28, color: AppColors.active),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asset Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Assign company assets to employees and track active inventory assignments.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFF414A51)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                  label: const Text('Asset Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => context.push('/asset-settings'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF414A51),
                    side: const BorderSide(color: Color(0xFF414A51)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.view_column_outlined, size: 18),
                  label: const Text('Columns', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AssetColumnSelectionDialog(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                  label: const Text('Assign Asset'),
                  onPressed: () => _showAssignAssetDialog(
                    employees: employees,
                    assetTypes: assetTypes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Card Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Controls Row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by employee, asset or reason...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            ref.read(assignmentSearchQueryProvider.notifier).state = val;
                          },
                        ),
                      ),

                      // Filter by Employee
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: empFilter,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter Employee',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Employees'),
                            ),
                            ...employees.map((e) {
                              return DropdownMenuItem<int?>(
                                value: e.id,
                                child: Text(e.fullName),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            ref.read(assignmentEmployeeFilterProvider.notifier).state = val;
                          },
                        ),
                      ),

                      // Filter by Asset Type
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          initialValue: assetTypeFilter,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter Asset Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Asset Types'),
                            ),
                            ...assetTypes.map((t) {
                              return DropdownMenuItem<int?>(
                                value: t.id,
                                child: Text(t.name),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            ref.read(assignmentAssetTypeFilterProvider.notifier).state = val;
                          },
                        ),
                      ),

                      // Filter by Date Range (From Date - To Date)
                      SizedBox(
                        width: 250,
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: dateRangeFilter != null
                                ? '${DateFormat('dd/MM/yyyy').format(dateRangeFilter.start)} - ${DateFormat('dd/MM/yyyy').format(dateRangeFilter.end)}'
                                : '',
                          ),
                          decoration: InputDecoration(
                            labelText: 'From Date - To Date',
                            hintText: 'Select Date Range',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: const Icon(Icons.date_range, size: 18),
                            suffixIcon: dateRangeFilter != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      ref.read(assignmentDateRangeFilterProvider.notifier).state = null;
                                    },
                                  )
                                : null,
                          ),
                          onTap: () async {
                            final pickedRange = await showDialog<DateTimeRange>(
                              context: context,
                              builder: (context) => CustomDateRangePickerDialog(
                                initialDateRange: dateRangeFilter,
                              ),
                            );
                            if (pickedRange != null) {
                              ref.read(assignmentDateRangeFilterProvider.notifier).state = pickedRange;
                            }
                          },
                        ),
                      ),
                      // Filter by Status
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String?>(
                          initialValue: statusFilter,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Statuses'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Assigned',
                              child: Text('Assigned'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Returned',
                              child: Text('Returned'),
                            ),
                            DropdownMenuItem<String?>(
                              value: 'Maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged: (val) {
                            ref.read(assignmentStatusFilterProvider.notifier).state = val;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  assignmentsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Error loading asset assignments: $err',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    data: (records) {
                      final filtered = records.where((r) {
                        if (empFilter != null && r.employeeId != empFilter) return false;
                        if (assetTypeFilter != null && r.assetTypeId != assetTypeFilter) return false;
                        if (statusFilter != null && r.status != statusFilter) return false;
                        if (dateRangeFilter != null) {
                          final rDate = DateTime.tryParse(r.assignedDate) ?? DateFormat('yyyy-MM-dd').tryParse(r.assignedDate);
                          if (rDate != null) {
                            final startDay = DateTime(dateRangeFilter.start.year, dateRangeFilter.start.month, dateRangeFilter.start.day, 0, 0, 0);
                            final endDay = DateTime(dateRangeFilter.end.year, dateRangeFilter.end.month, dateRangeFilter.end.day, 23, 59, 59, 999);
                            if (rDate.isBefore(startDay) || rDate.isAfter(endDay)) return false;
                          }
                        }
                        if (searchQuery.trim().isNotEmpty) {
                          final q = searchQuery.toLowerCase();
                          final matchEmp = r.employeeName.toLowerCase().contains(q) ||
                              r.employeeCode.toLowerCase().contains(q);
                          final matchAssetType = r.assetTypeName.toLowerCase().contains(q);
                          final matchAssetName = r.assetName.toLowerCase().contains(q);
                          final matchSerial = r.serialNumber.toLowerCase().contains(q);
                          final matchDesc = r.description.toLowerCase().contains(q);
                          final matchMaint = (r.maintenanceAddress?.toLowerCase().contains(q) ?? false) ||
                              (r.maintenanceContact?.toLowerCase().contains(q) ?? false);
                          if (!matchEmp && !matchAssetType && !matchAssetName && !matchSerial && !matchDesc && !matchMaint) return false;
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          child: const Column(
                            children: [
                              Icon(Icons.assignment_outlined, size: 48, color: AppColors.textSecondary),
                              SizedBox(height: 12),
                              Text('No asset assignments found.',
                                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8F9FA),
                                ),
                                columns: visibleColumns.map((col) {
                                  return DataColumn(
                                    label: Text(
                                      col,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  );
                                }).toList(),
                                rows: filtered.map((record) {
                                  final isAssigned = record.status == 'Assigned';
                                  final isReturned = record.status == 'Returned';
                                  final isMaintenance = record.status == 'Maintenance';

                                  return DataRow(
                                    cells: visibleColumns.map((col) {
                                      switch (col) {
                                        case 'Assigned To':
                                          return DataCell(
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record.employeeName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                if (record.employeeCode.isNotEmpty)
                                                  Text(
                                                    record.employeeCode,
                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                  ),
                                              ],
                                            ),
                                          );
                                        case 'Asset Name':
                                          return DataCell(
                                            Text(
                                              record.assetName.isNotEmpty ? record.assetName : '-',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: record.assetName.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                                color: record.assetName.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                                              ),
                                            ),
                                          );
                                        case 'Asset Type':
                                          return DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.active.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                record.assetTypeName,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          );
                                        case 'Serial Number':
                                          return DataCell(
                                            Text(
                                              record.serialNumber.isNotEmpty ? record.serialNumber : '-',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: record.serialNumber.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                                color: record.serialNumber.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                                              ),
                                            ),
                                          );
                                        case 'Assigned Date':
                                          return DataCell(
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                                const SizedBox(width: 6),
                                                Text(record.assignedDate),
                                              ],
                                            ),
                                          );
                                        case 'Reason / Description':
                                          return DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 250),
                                              child: Text(
                                                record.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ),
                                          );
                                        case 'Status':
                                          return DataCell(
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isAssigned
                                                        ? Colors.blue.withValues(alpha: 0.1)
                                                        : (isReturned
                                                            ? Colors.grey.withValues(alpha: 0.1)
                                                            : Colors.orange.withValues(alpha: 0.1)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    record.status,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isAssigned
                                                          ? Colors.blue[800]
                                                          : (isReturned ? Colors.grey[700] : Colors.orange[900]),
                                                    ),
                                                  ),
                                                ),
                                                if (isMaintenance &&
                                                    ((record.maintenanceAddress?.isNotEmpty ?? false) ||
                                                        (record.maintenanceGivenDate?.isNotEmpty ?? false))) ...[
                                                  const SizedBox(height: 3),
                                                  Tooltip(
                                                    message:
                                                        'Address: ${record.maintenanceAddress ?? "N/A"}\nContact: ${record.maintenanceContact ?? "N/A"}\nGiven: ${record.maintenanceGivenDate ?? "N/A"}\nReturn: ${record.maintenanceReturnDate ?? "N/A"}',
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.build, size: 10, color: Colors.orange),
                                                        const SizedBox(width: 3),
                                                        ConstrainedBox(
                                                          constraints: const BoxConstraints(maxWidth: 140),
                                                          child: Text(
                                                            'G: ${record.maintenanceGivenDate ?? "-"} | R: ${record.maintenanceReturnDate ?? "-"}',
                                                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        case 'Actions':
                                          return DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.textSecondary),
                                                  tooltip: 'View Details',
                                                  onPressed: () => _showViewAssignmentDialog(record),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.active),
                                                  tooltip: 'Edit Assignment',
                                                  onPressed: () => _showAssignAssetDialog(
                                                    assignmentToEdit: record,
                                                    employees: employees,
                                                    assetTypes: assetTypes,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                  tooltip: 'Remove Assignment Record',
                                                  onPressed: () => _confirmDeleteAssignment(record),
                                                ),
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
                          );
                        },
                      );
                    },
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
