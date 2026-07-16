import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({super.key, required this.onPressed, this.isLoading = false});
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 18)),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF22282D),
        side: const BorderSide(color: Color(0xFFDDE1E5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
