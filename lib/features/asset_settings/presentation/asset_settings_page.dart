import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/asset_type.dart';
import '../providers/asset_settings_providers.dart';

class AssetSettingsPage extends ConsumerStatefulWidget {
  const AssetSettingsPage({super.key});

  @override
  ConsumerState<AssetSettingsPage> createState() => _AssetSettingsPageState();
}

class _AssetSettingsPageState extends ConsumerState<AssetSettingsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({AssetType? typeToEdit}) {
    final isEditing = typeToEdit != null;
    final nameController = TextEditingController(text: typeToEdit?.name ?? '');
    final descController = TextEditingController(text: typeToEdit?.description ?? '');
    String selectedCategory = typeToEdit?.category ?? 'Hardware';
    String selectedStatus = typeToEdit?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Asset Type' : 'Add New Asset Type',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Asset Type Name *',
                            hintText: 'e.g. Laptop, Mobile Phone, Monitor',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Asset type name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Hardware', child: Text('Hardware')),
                            DropdownMenuItem(value: 'Peripheral', child: Text('Peripheral')),
                            DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                            DropdownMenuItem(value: 'Office', child: Text('Office Equipment')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedStatus = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Provide details about this asset category...',
                            border: OutlineInputBorder(),
                          ),
                        ),
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
                  label: Text(isEditing ? 'Save Changes' : 'Create Asset Type'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext);

                    final repo = ref.read(assetTypeRepositoryProvider);
                    if (isEditing) {
                      final updated = typeToEdit.copyWith(
                        name: nameController.text.trim(),
                        category: selectedCategory,
                        status: selectedStatus,
                        description: descController.text.trim(),
                      );
                      await repo.updateAssetType(updated);
                    } else {
                      final newType = AssetType(
                        id: 0,
                        name: nameController.text.trim(),
                        category: selectedCategory,
                        status: selectedStatus,
                        description: descController.text.trim(),
                      );
                      await repo.addAssetType(newType);
                    }
                    ref.invalidate(assetTypesProvider);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(AssetType type) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Asset Type'),
          content: Text('Are you sure you want to remove "${type.name}"?'),
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
                await ref.read(assetTypeRepositoryProvider).deleteAssetType(type.id);
                ref.invalidate(assetTypesProvider);
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
    final assetTypesAsync = ref.watch(assetTypesProvider);
    final searchQuery = ref.watch(assetTypeSearchQueryProvider);

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
                const Icon(Icons.settings_suggest_outlined, size: 28, color: AppColors.active),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asset Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Define and manage equipment types (Laptops, Phones, Monitors, Keyboards, etc.)',
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
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Asset Type'),
                  onPressed: () => _showAddEditDialog(),
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
                  // Search Row
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search asset types...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        ref.read(assetTypeSearchQueryProvider.notifier).state = val;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  assetTypesAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Error loading asset types: $err',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    data: (types) {
                      final filtered = types.where((t) {
                        if (searchQuery.trim().isEmpty) return true;
                        final q = searchQuery.toLowerCase();
                        return t.name.toLowerCase().contains(q) ||
                            t.category.toLowerCase().contains(q) ||
                            t.description.toLowerCase().contains(q);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          child: const Column(
                            children: [
                              Icon(Icons.devices_other, size: 48, color: AppColors.textSecondary),
                              SizedBox(height: 12),
                              Text('No asset types found.',
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
                                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Asset Type Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filtered.map((type) {
                                  final isActive = type.status == 'Active';
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('#${type.id}')),
                                      DataCell(
                                        Row(
                                          children: [
                                            _getIconForAssetType(type.name),
                                            const SizedBox(width: 10),
                                            Text(
                                              type.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
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
                                            type.category,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          type.description.isEmpty ? '—' : type.description,
                                          style: const TextStyle(color: AppColors.textSecondary),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Colors.green.withValues(alpha: 0.1)
                                                : Colors.grey.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            type.status,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? Colors.green[800] : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.active),
                                              tooltip: 'Edit Asset Type',
                                              onPressed: () => _showAddEditDialog(typeToEdit: type),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              tooltip: 'Remove Asset Type',
                                              onPressed: () => _confirmDelete(type),
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

  Widget _getIconForAssetType(String name) {
    final lower = name.toLowerCase();
    IconData icon = Icons.devices_other;
    if (lower.contains('laptop') || lower.contains('computer')) {
      icon = Icons.laptop;
    } else if (lower.contains('phone') || lower.contains('mobile')) {
      icon = Icons.smartphone;
    } else if (lower.contains('monitor') || lower.contains('screen')) {
      icon = Icons.desktop_windows;
    } else if (lower.contains('keyboard')) {
      icon = Icons.keyboard;
    } else if (lower.contains('headset') || lower.contains('headphone')) {
      icon = Icons.headset;
    }
    return Icon(icon, size: 20, color: AppColors.active);
  }
}
