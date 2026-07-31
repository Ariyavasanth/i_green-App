import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../asset_settings/domain/asset_type.dart';
import '../../asset_settings/providers/asset_settings_providers.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/asset_assignment.dart';
import '../providers/asset_management_providers.dart';

class AssetManagementPage extends ConsumerStatefulWidget {
  const AssetManagementPage({super.key});

  @override
  ConsumerState<AssetManagementPage> createState() => _AssetManagementPageState();
}

class _AssetManagementPageState extends ConsumerState<AssetManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    AssetType? selectedAssetType;
    if (isEditing) {
      final matches = assetTypes.where((a) => a.id == assignmentToEdit.assetTypeId).toList();
      if (matches.isNotEmpty) {
        selectedAssetType = matches.first;
      }
    }

    final dateController = TextEditingController(
      text: isEditing
          ? assignmentToEdit.assignedDate
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    final descController = TextEditingController(
      text: isEditing ? assignmentToEdit.description : '',
    );

    String selectedStatus = isEditing ? assignmentToEdit.status : 'Assigned';
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Update Asset Assignment' : 'Assign Asset to Employee',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Select Employee
                        DropdownButtonFormField<Employee>(
                          initialValue: selectedEmployee,
                          decoration: const InputDecoration(
                            labelText: 'Select Employee *',
                            border: OutlineInputBorder(),
                          ),
                          items: employees.map((emp) {
                            final codeStr = emp.employeeId.isNotEmpty ? ' (${emp.employeeId})' : '';
                            return DropdownMenuItem<Employee>(
                              value: emp,
                              child: Text('${emp.fullName}$codeStr'),
                            );
                          }).toList(),
                          validator: (val) {
                            if (val == null) return 'Please select an employee';
                            return null;
                          },
                          onChanged: (val) {
                            setDialogState(() => selectedEmployee = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Select Asset Type
                        DropdownButtonFormField<AssetType>(
                          initialValue: selectedAssetType,
                          decoration: const InputDecoration(
                            labelText: 'Select Asset Type *',
                            border: OutlineInputBorder(),
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
                            setDialogState(() => selectedAssetType = val);
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
                        const SizedBox(height: 14),

                        // Assignment Reason / Description
                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason for Assignment / Description *',
                            hintText: 'Enter reason for assigning asset (e.g., New joiner requirement, hardware upgrade)...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a description or reason';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        if (isEditing) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Assignment Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                              DropdownMenuItem(value: 'Returned', child: Text('Returned')),
                              DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedStatus = val);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEditing ? 'Update Record' : 'Assign Asset'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext);

                    final repo = ref.read(assetAssignmentRepositoryProvider);
                    if (isEditing) {
                      final updated = assignmentToEdit.copyWith(
                        employeeId: selectedEmployee!.id,
                        employeeName: selectedEmployee!.fullName,
                        employeeCode: selectedEmployee!.employeeId,
                        assetTypeId: selectedAssetType!.id,
                        assetTypeName: selectedAssetType!.name,
                        assignedDate: dateController.text.trim(),
                        description: descController.text.trim(),
                        status: selectedStatus,
                      );
                      await repo.updateAssignment(updated);
                    } else {
                      final newAssignment = AssetAssignment(
                        id: 0,
                        employeeId: selectedEmployee!.id,
                        employeeName: selectedEmployee!.fullName,
                        employeeCode: selectedEmployee!.employeeId,
                        assetTypeId: selectedAssetType!.id,
                        assetTypeName: selectedAssetType!.name,
                        assignedDate: dateController.text.trim(),
                        description: descController.text.trim(),
                        status: 'Assigned',
                      );
                      await repo.addAssignment(newAssignment);
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
                        if (searchQuery.trim().isNotEmpty) {
                          final q = searchQuery.toLowerCase();
                          final matchEmp = r.employeeName.toLowerCase().contains(q) ||
                              r.employeeCode.toLowerCase().contains(q);
                          final matchAsset = r.assetTypeName.toLowerCase().contains(q);
                          final matchDesc = r.description.toLowerCase().contains(q);
                          if (!matchEmp && !matchAsset && !matchDesc) return false;
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
                                columns: const [
                                  DataColumn(label: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Asset Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Assigned Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Reason / Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filtered.map((record) {
                                  final isAssigned = record.status == 'Assigned';
                                  final isReturned = record.status == 'Returned';

                                  return DataRow(
                                    cells: [
                                      DataCell(
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
                                      ),
                                      DataCell(
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
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 6),
                                            Text(record.assignedDate),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 250),
                                          child: Text(
                                            record.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ),
                                      DataCell(
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
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
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
                                      ),
                                    ],
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
