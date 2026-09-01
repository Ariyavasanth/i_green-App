import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A compact, searchable dropdown that opens an inline dropdown menu
/// directly beneath the input field (not a separate centered popup).
class AppSearchableDropdown<T> extends StatefulWidget {
  const AppSearchableDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.placeholder,
    this.searchHint = 'Search...',
    this.isRequired = false,
    this.isExpanded = true,
    this.enabled = true,
    this.validator,
  });

  final String? label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item)? itemLabel;
  final String? placeholder;
  final String searchHint;
  final bool isRequired;
  final bool isExpanded;
  final bool enabled;
  final FormFieldValidator<T>? validator;

  @override
  State<AppSearchableDropdown<T>> createState() =>
      _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  String _getItemLabel(T item) {
    if (widget.itemLabel != null) return widget.itemLabel!(item);
    return item.toString();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (_isOpen && mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _toggleDropdown(FormFieldState<T> state) {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showDropdown(state);
    }
  }

  void _showDropdown(FormFieldState<T> state) {
    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - (offset.dy + size.height);
    const dropdownHeight = 260.0;
    final showAbove = spaceBelow < dropdownHeight && offset.dy > dropdownHeight;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Barrier to close dropdown on tap outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          // Anchored dropdown menu directly beneath the trigger field
          Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: showAbove
                  ? const Offset(0, -dropdownHeight - 4)
                  : Offset(0, size.height + 4),
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: dropdownHeight),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0D5DD), width: 0.8),
                  ),
                  child: _DropdownMenuContent<T>(
                    items: widget.items,
                    selectedValue: widget.value,
                    searchHint: widget.searchHint,
                    itemLabel: _getItemLabel,
                    onSelected: (val) {
                      state.didChange(val);
                      widget.onChanged(val);
                      _removeOverlay();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null &&
        (widget.value is! String || (widget.value as String).isNotEmpty);
    final displayText =
        hasValue ? _getItemLabel(widget.value as T) : (widget.placeholder ?? 'Select option');

    final fieldWidget = FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        final hasError = state.hasError;

        return CompositedTransformTarget(
          link: _layerLink,
          child: Column(
            key: _fieldKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: widget.enabled ? () => _toggleDropdown(state) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: widget.enabled ? Colors.white : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasError
                          ? Colors.red
                          : (_isOpen ? AppColors.primary : const Color(0xFFD0D5DD)),
                      width: _isOpen ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayText,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasValue
                                ? (widget.enabled ? Colors.black87 : Colors.black54)
                                : Colors.black38,
                            fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 4),
                Text(
                  state.errorText ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (widget.label == null || widget.label!.isEmpty) {
      return fieldWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelWithRequiredStar(widget.label!),
        const SizedBox(height: 5),
        fieldWidget,
      ],
    );
  }

  Widget _buildLabelWithRequiredStar(String rawLabel) {
    final showStar = widget.isRequired || rawLabel.contains('*');
    final cleanLabel = rawLabel.replaceAll('*', '').trim();

    return RichText(
      text: TextSpan(
        text: cleanLabel,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        children: [
          if (showStar)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _DropdownMenuContent<T> extends StatefulWidget {
  const _DropdownMenuContent({
    required this.items,
    required this.selectedValue,
    required this.searchHint,
    required this.itemLabel,
    required this.onSelected,
  });

  final List<T> items;
  final T? selectedValue;
  final String searchHint;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onSelected;

  @override
  State<_DropdownMenuContent<T>> createState() => _DropdownMenuContentState<T>();
}

class _DropdownMenuContentState<T> extends State<_DropdownMenuContent<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items.where((item) {
      if (_query.trim().isEmpty) return true;
      final label = widget.itemLabel(item).toLowerCase();
      return label.contains(_query.trim().toLowerCase());
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Search Field at the top of the dropdown menu
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: const TextStyle(fontSize: 11.5, color: Colors.black38),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
              prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              suffixIcon: _query.isNotEmpty
                  ? InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.clear, size: 14, color: Color(0xFF94A3B8)),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
                borderSide: BorderSide(color: AppColors.primary, width: 1.2),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // Compact Scrollable Items List
        Flexible(
          child: filteredItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Center(
                    child: Text(
                      'No matching options',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = widget.selectedValue != null &&
                          widget.selectedValue == item;
                      final label = widget.itemLabel(item);

                      return InkWell(
                        onTap: () => widget.onSelected(item),
                        borderRadius: BorderRadius.circular(5),
                        hoverColor: const Color(0xFFF1F5F9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFF334155),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
