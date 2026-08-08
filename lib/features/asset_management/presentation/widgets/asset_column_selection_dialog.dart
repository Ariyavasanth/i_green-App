import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/asset_management_providers.dart';

class AssetColumnSelectionDialog extends ConsumerStatefulWidget {
  const AssetColumnSelectionDialog({super.key});

  @override
  ConsumerState<AssetColumnSelectionDialog> createState() => _AssetColumnSelectionDialogState();
}

class _AssetColumnSelectionDialogState extends ConsumerState<AssetColumnSelectionDialog> {
  late List<String> _orderedColumns;
  late Set<String> _visibleColumns;

  @override
  void initState() {
    super.initState();
    final allColumns = ref.read(assetAllColumnsProvider);
    final currentOrder = ref.read(assetColumnOrderProvider);
    final currentVisible = ref.read(assetVisibleColumnsProvider);

    final ordered = <String>[...currentOrder];
    for (final col in allColumns) {
      if (!ordered.contains(col)) {
        ordered.add(col);
      }
    }
    _orderedColumns = ordered;
    _visibleColumns = currentVisible.toSet();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _orderedColumns.removeAt(oldIndex);
      _orderedColumns.insert(newIndex, item);
    });
  }

  void _moveUp(int index) {
    if (index > 0) {
      _onReorder(index, index - 1);
    }
  }

  void _moveDown(int index) {
    if (index < _orderedColumns.length - 1) {
      _onReorder(index, index + 2);
    }
  }

  void _resetToDefault() {
    final all = ref.read(assetAllColumnsProvider);
    setState(() {
      _orderedColumns = List.from(all);
      _visibleColumns = all.toSet();
    });
  }

  void _save() {
    if (_visibleColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one column must be visible.')),
      );
      return;
    }

    final newVisible = _orderedColumns.where((col) => _visibleColumns.contains(col)).toList();
    ref.read(assetColumnOrderProvider.notifier).state = List.from(_orderedColumns);
    ref.read(assetVisibleColumnsProvider.notifier).state = newVisible;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.view_column_outlined, color: AppColors.active),
          const SizedBox(width: 8),
          const Text(
            'Column Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select columns to display and drag or use arrows to reorder:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ReorderableListView.builder(
                    itemCount: _orderedColumns.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final column = _orderedColumns[index];
                      final isVisible = _visibleColumns.contains(column);
                      return Material(
                        key: ValueKey(column),
                        color: Colors.transparent,
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.divider),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isVisible,
                                  activeColor: AppColors.active,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _visibleColumns.add(column);
                                      } else {
                                        _visibleColumns.remove(column);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    column,
                                    style: TextStyle(
                                      fontWeight: isVisible
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isVisible
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Move Up',
                                  onPressed: index > 0 ? () => _moveUp(index) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Move Down',
                                  onPressed: index < _orderedColumns.length - 1
                                      ? () => _moveDown(index)
                                      : null,
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetToDefault,
          child: const Text('Reset to Default'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.active),
          onPressed: _save,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
