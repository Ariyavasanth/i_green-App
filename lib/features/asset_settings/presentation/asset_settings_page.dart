import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/asset_category.dart';
import '../domain/asset_type.dart';
import '../providers/asset_settings_providers.dart';

class AssetSettingsPage extends ConsumerStatefulWidget {
  const AssetSettingsPage({super.key});

  @override
  ConsumerState<AssetSettingsPage> createState() => _AssetSettingsPageState();
}

class _AssetSettingsPageState extends ConsumerState<AssetSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                    backgroundColor: const Color(0xFF9CC70A),
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
                backgroundColor: const Color(0xFF9CC70A),
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
    const primaryColor = Color(0xFF9CC70A);
    final assetTypesAsync = ref.watch(assetTypesProvider);
    final assetCategoriesAsync = ref.watch(assetCategoriesProvider);
    final searchQuery = ref.watch(assetTypeSearchQueryProvider);
    final assetTypes = assetTypesAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.grid_view, color: Color(0xFF1E293B)),
          onPressed: () {},
        ),
        title: const Text(
          'Asset Settings',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF414A51)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF414A51)),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: primaryColor,
              child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Asset Types'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // View 1: Asset Types List
          _buildAssetTypesView(assetTypesAsync, searchQuery),
          // View 2: Categories List
          _buildCategoriesView(assetCategoriesAsync, assetTypes),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEditDialog();
          } else {
            _showAddEditCategoryDialog();
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Add Asset Type' : 'Add Category',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildAssetTypesView(
    AsyncValue<List<AssetType>> assetTypesAsync,
    String searchQuery,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search asset types...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (val) {
              ref.read(assetTypeSearchQueryProvider.notifier).state = val;
            },
          ),
        ),
        Expanded(
          child: assetTypesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading asset types: $err')),
            data: (types) {
              final filtered = types.where((t) {
                if (searchQuery.trim().isEmpty) return true;
                final q = searchQuery.toLowerCase();
                return t.name.toLowerCase().contains(q) ||
                    t.category.toLowerCase().contains(q) ||
                    t.description.toLowerCase().contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.devices_other, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No asset types found.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildAssetTypeCard(filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAssetTypeCard(AssetType type) {
    const primaryColor = Color(0xFF9CC70A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _getIconForAssetType(type.name),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${type.id}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  type.description.isEmpty ? 'No description provided' : type.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF414A51),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF414A51)),
                    onPressed: () => _showAddEditDialog(typeToEdit: type),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _confirmDelete(type),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesView(
    AsyncValue<List<AssetCategory>> assetCategoriesAsync,
    List<AssetType> assetTypes,
  ) {
    return assetCategoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading categories: $err')),
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.category_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text(
                    'No categories found.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildCategoryCard(categories[index], assetTypes),
        );
      },
    );
  }

  Widget _buildCategoryCard(AssetCategory category, List<AssetType> assetTypes) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF414A51).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.category_outlined, color: Color(0xFF414A51), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description.isEmpty ? 'No description provided' : category.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF414A51)),
                onPressed: () => _showAddEditCategoryDialog(categoryToEdit: category),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _confirmDeleteCategory(category, assetTypes),
              ),
            ],
          ),
        ],
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
    return Icon(icon, size: 22, color: const Color(0xFF9CC70A));
  }
}
