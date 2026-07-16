import 'package:flutter/material.dart';

class CustomerTextField extends StatelessWidget {
  const CustomerTextField({required this.controller, required this.label, this.required = false, this.validator, this.keyboardType, this.maxLines = 1, this.prefix, super.key});
  final TextEditingController controller;
  final String label;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? prefix;
  @override Widget build(BuildContext context) => TextFormField(
    controller: controller, keyboardType: keyboardType, maxLines: maxLines,
    decoration: InputDecoration(labelText: required ? '$label *' : label, prefixIcon: prefix, border: const OutlineInputBorder()),
    validator: validator ?? (required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null),
  );
}

class ResponsiveFieldGrid extends StatelessWidget {
  const ResponsiveFieldGrid({required this.children, super.key});
  final List<Widget> children;
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final columns = c.maxWidth >= 900 ? 3 : c.maxWidth >= 600 ? 2 : 1;
    const gap = 14.0;
    final width = (c.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(spacing: gap, runSpacing: gap, children: children.map((e) => SizedBox(width: width, child: e)).toList());
  });
}

class PhoneField extends StatelessWidget {
  const PhoneField({required this.controller, required this.label, super.key});
  final TextEditingController controller;
  final String label;
  @override Widget build(BuildContext context) => CustomerTextField(
    controller: controller, label: label, keyboardType: TextInputType.phone,
    prefix: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Center(widthFactor: 1, child: Text('+91'))),
  );
}
