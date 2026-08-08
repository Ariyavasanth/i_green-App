import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/asset_category.dart';
import '../domain/asset_type.dart';
import '../providers/asset_settings_providers.dart';

class AssetSettingsPage extends ConsumerStatefulWidget {
  const AssetSettingsPage({super.key});

  @override
  ConsumerState<AssetSettingsPage> createState() => _AssetSettingsPageState();
}

class _AssetSettingsPageState extends ConsumerState<AssetSettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Asset Types, 1: Categories

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

    final categoriesAsync = ref.read(assetCategoriesProvider);
    final categoriesList = categoriesAsync.asData?.value ?? [];
    final categoryOptions = categoriesList.isNotEmpty
        ? categoriesList.map((c) => c.name).toList()
        : ['Hardware', 'Peripheral', 'Software', 'Network', 'Other'];

    if (!categoryOptions.contains(selectedCategory) && categoryOptions.isNotEmpty) {
      categoryOptions.add(selectedCategory);
    }

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
                          items: categoryOptions.map((catName) {
                            return DropdownMenuItem(
                              value: catName,
                              child: Text(catName),
                            );
                          }).toList(),
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

  void _showAddEditCategoryDialog({AssetCategory? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    final descController = TextEditingController(text: categoryToEdit?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Category' : 'Add Category',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
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
                        labelText: 'Category Name *',
                        hintText: 'Enter category name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Category name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Enter description (optional)',
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext);

                final repo = ref.read(assetCategoryRepositoryProvider);
                if (isEditing) {
                  final updated = categoryToEdit.copyWith(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                  );
                  await repo.updateAssetCategory(updated);
                } else {
                  final newCategory = AssetCategory(
                    id: 0,
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                  );
                  await repo.addAssetCategory(newCategory);
                }
                ref.invalidate(assetCategoriesProvider);
                ref.invalidate(assetTypesProvider);
              },
              child: Text(isEditing ? 'Update' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(AssetCategory category, List<AssetType> assetTypes) {
    final count = assetTypes
        .where((t) => t.category.trim().toLowerCase() == category.name.trim().toLowerCase())
        .length;

    if (count > 0) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Delete Category'),
              ],
            ),
            content: Text(
              'Category "${category.name}" is currently used in $count asset type(s).\n\nYou cannot delete a category that is currently used in an asset.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Category'),
              ],
            ),
            content: Text('Are you sure you want to delete category "${category.name}"?'),
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
                  await ref.read(assetCategoryRepositoryProvider).deleteAssetCategory(category.id);
                  ref.invalidate(assetCategoriesProvider);
                  ref.invalidate(assetTypesProvider);
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetTypesAsync = ref.watch(assetTypesProvider);
    final assetCategoriesAsync = ref.watch(assetCategoriesProvider);
    final searchQuery = ref.watch(assetTypeSearchQueryProvider);
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
                  label: Text(_selectedTab == 0 ? 'Add Asset Type' : 'Add Category'),
                  onPressed: () {
                    if (_selectedTab == 0) {
                      _showAddEditDialog();
                    } else {
                      _showAddEditCategoryDialog();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Navigation
            Row(
              children: [
                _buildTabButton(
                  title: 'Asset Types',
                  index: 0,
                ),
                const SizedBox(width: 24),
                _buildTabButton(
                  title: 'Categories',
                  index: 1,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Content
            if (_selectedTab == 0)
              _buildAssetTypesTab(assetTypesAsync, searchQuery)
            else
              _buildCategoriesTab(assetCategoriesAsync, assetTypes),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            height: 3,
            width: title.length * 9.0 + 8.0,
            color: isActive ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTypesTab(
    AsyncValue<List<AssetType>> assetTypesAsync,
    String searchQuery,
  ) {
    return Container(
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
    );
  }

  Widget _buildCategoriesTab(
    AsyncValue<List<AssetCategory>> assetCategoriesAsync,
    List<AssetType> assetTypes,
  ) {
    return assetCategoriesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Error loading categories: $err',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (categories) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 900;
            return isWideScreen
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCategoriesTableCard(categories, assetTypes),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 340,
                        child: _buildCategoriesRightPanel(categories, assetTypes),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoriesTableCard(categories, assetTypes),
                      const SizedBox(height: 20),
                      _buildCategoriesRightPanel(categories, assetTypes),
                    ],
                  );
          },
        );
      },
    );
  }

  Widget _buildCategoriesTableCard(
    List<AssetCategory> categories,
    List<AssetType> assetTypes,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Card Header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage asset categories',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Category'),
                onPressed: () => _showAddEditCategoryDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (categories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              child: const Column(
                children: [
                  Icon(Icons.category_outlined, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No categories found.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            )
          else
            LayoutBuilder(
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
                        DataColumn(label: Text('Category Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: categories.map((cat) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${cat.id}')),
                            DataCell(
                              Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataCell(
                              Text(
                                cat.description.isEmpty ? '—' : cat.description,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.active),
                                    tooltip: 'Edit Category',
                                    onPressed: () => _showAddEditCategoryDialog(categoryToEdit: cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: 'Delete Category',
                                    onPressed: () => _confirmDeleteCategory(cat, assetTypes),
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
            ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'Total ${categories.length} categories',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRightPanel(
    List<AssetCategory> categories,
    List<AssetType> assetTypes,
  ) {
    return Column(
      children: [
        // Note Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'You cannot delete a category that is currently used in an asset.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Usage Summary Card
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
              const Text(
                'Category Usage Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (categories.isEmpty)
                const Text('No categories available', style: TextStyle(color: AppColors.textSecondary))
              else
                ...categories.map((cat) {
                  final usageCount = assetTypes
                      .where((t) => t.category.trim().toLowerCase() == cat.name.trim().toLowerCase())
                      .length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '$usageCount assets',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
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
