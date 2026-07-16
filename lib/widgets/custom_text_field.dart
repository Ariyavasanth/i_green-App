import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({super.key, required this.controller, required this.label, required this.hint, required this.validator, this.keyboardType, this.prefixIcon, this.maxLength});
  final TextEditingController controller;
  final String label, hint;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final int? maxLength;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller, keyboardType: keyboardType, maxLength: maxLength, validator: validator,
    decoration: InputDecoration(
      labelText: label, hintText: hint, counterText: '', prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDE1E5))),
    ),
  );
}
