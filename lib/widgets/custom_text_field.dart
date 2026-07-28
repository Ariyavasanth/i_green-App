import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.maxLength,
    this.obscureText = false,
  });
  final TextEditingController controller;
  final String label, hint;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final int? maxLength;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLength: maxLength,
    validator: validator,
    obscureText: obscureText,
    style: Theme.of(context).textTheme.bodyMedium,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 17),
    ),
  );
}
