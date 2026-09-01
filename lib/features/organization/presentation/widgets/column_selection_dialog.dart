import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/column_preference.dart';
import '../../providers/organization_providers.dart';

class ColumnSelectionDialog extends ConsumerStatefulWidget {
  const ColumnSelectionDialog({
    required this.tableId,
    required this.allColumns,
    required this.currentVisibleColumns,
    required this.currentColumnOrder,
    super.key,
  });

  final String tableId;
  final List<String> allColumns;
  final List<String> currentVisibleColumns;
  final List<String> currentColumnOrder;

  static Future<void> show(
    BuildContext context, {
    required String tableId,
    required List<String> allColumns,
    ColumnPreference? currentPreferences,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: tableId,
        allColumns: allColumns,
        currentVisibleColumns: (currentPreferences != null &&
                currentPreferences.visibleColumns.isNotEmpty)
            ? currentPreferences.visibleColumns
            : allColumns,
        currentColumnOrder: (currentPreferences != null &&
                currentPreferences.columnOrder.isNotEmpty)
            ? currentPreferences.columnOrder
            : allColumns,
      ),
    );
  }

  @override
  ConsumerState<ColumnSelectionDialog> createState() =>
      _ColumnSelectionDialogState();
}

class _ColumnSelectionDialogState
    extends ConsumerState<ColumnSelectionDialog> {
  late List<String> _orderedColumns;
  late Set<String> _visibleColumns;

  @override
  void initState() {
    super.initState();
    // Initialize ordered columns with existing order plus any missing default columns
    final existingOrder = widget.currentColumnOrder.isNotEmpty
        ? widget.currentColumnOrder
        : widget.allColumns;

    final ordered = <String>[...existingOrder];
    for (final col in widget.allColumns) {
      if (!ordered.contains(col)) {
        ordered.add(col);
      }
    }
    _orderedColumns = ordered;

    _visibleColumns = widget.currentVisibleColumns.isNotEmpty
        ? widget.currentVisibleColumns.toSet()
        : widget.allColumns.toSet();
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
    setState(() {
      _orderedColumns = List.from(widget.allColumns);
      _visibleColumns = widget.allColumns.toSet();
    });
  }

  Future<void> _save() async {
    // Ensure at least one column is visible
    if (_visibleColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one column must be visible.'),
        ),
      );
      return;
    }

    final pref = ColumnPreference(
      tableId: widget.tableId,
      visibleColumns: _orderedColumns
          .where((col) => _visibleColumns.contains(col))
          .toList(),
      columnOrder: _orderedColumns,
    );

    await ref.read(organizationRepositoryProvider).saveColumnPreference(pref);
    await ref.read(employeeRepositoryProvider).saveColumnPreference(pref);
    ref.invalidate(columnPreferenceProvider(widget.tableId));
    ref.invalidate(empColumnPreferenceProvider(widget.tableId));
    if (mounted) Navigator.of(context).pop(true);
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
