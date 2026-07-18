import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A labeled search-as-you-type field backed by an in-memory option list.
///
/// Wraps [RawAutocomplete] with the app's input styling and a leading search
/// icon so it matches the plain [TextField]s used across the rest of the
/// app while still supporting a "type or click to select" workflow.
class SearchableField<T extends Object> extends StatefulWidget {
  const SearchableField({
    required this.label,
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
    this.controller,
    this.required = false,
    this.hintText,
    this.optionSubtitle,
    this.validator,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<T> options;
  final String Function(T) displayStringForOption;
  final ValueChanged<T> onSelected;
  final TextEditingController? controller;
  final bool required;
  final String? hintText;
  final String? Function(T)? optionSubtitle;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<SearchableField<T>> createState() => _SearchableFieldState<T>();
}

class _SearchableFieldState<T extends Object> extends State<SearchableField<T>> {
  TextEditingController? _ownedController;
  final _focusNode = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void dispose() {
    _ownedController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<T>(
    textEditingController: _controller,
    focusNode: _focusNode,
    optionsBuilder: (value) {
      if (value.text.isEmpty) return widget.options;
      final query = value.text.toLowerCase();
      return widget.options.where(
        (o) => widget.displayStringForOption(o).toLowerCase().contains(query),
      );
    },
    displayStringForOption: widget.displayStringForOption,
    onSelected: widget.onSelected,
    fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label}*' : widget.label,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      focusNode.requestFocus();
                    },
                  ),
          ),
        ),
    optionsViewBuilder: (context, onSelectedOption, values) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        color: AppColors.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260, minWidth: 260),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: values.length,
            itemBuilder: (context, index) {
              final option = values.elementAt(index);
              final subtitle = widget.optionSubtitle?.call(option);
              return ListTile(
                dense: true,
                title: Text(widget.displayStringForOption(option)),
                subtitle: subtitle == null || subtitle.isEmpty
                    ? null
                    : Text(subtitle, style: const TextStyle(fontSize: 11)),
                onTap: () => onSelectedOption(option),
              );
            },
          ),
        ),
      ),
    ),
  );
}
