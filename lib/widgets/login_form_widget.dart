import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/authentication_providers.dart';
import 'custom_text_field.dart';

class LoginFormWidget extends ConsumerStatefulWidget {
  const LoginFormWidget({super.key});
  @override
  ConsumerState<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends ConsumerState<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  bool _loading = false, _error = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email or Employee ID';
    return null;
  }

  String? _otpValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter password or verification code';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    final repository = ref.read(authenticationRepositoryProvider);
    try {
      final valid = await repository.verifyOtp(email: _email.text.trim(), otp: _otp.text);
      if (!mounted) return;
      if (valid) {
        final userEmail = _email.text.trim();
        ref.read(currentUserEmailProvider.notifier).state = userEmail;
        await ref.read(authSessionStorageProvider).writeUserEmail(userEmail);
        if (mounted) context.go('/home');
      } else {
        setState(() {
          _error = true;
          _message = 'Invalid username or password. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline, size: 34, color: Color(0xFF414A51)),
          const SizedBox(height: 28),
          Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF22282D))),
          const SizedBox(height: 8),
          const Text(
            'Sign in with your Email address or Employee ID and password.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _email,
            label: 'Email address or Employee ID',
            hint: 'you@example.com or EMP-9222',
            prefixIcon: Icons.person_outline,
            validator: _emailValidator,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _otp,
            label: 'Password or Verification Code',
            hint: 'Enter your password or code',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF69737A),
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            obscureText: _obscurePassword,
            validator: _otpValidator,
          ),
          if (_message != null) ...[const SizedBox(height: 18), _InfoMessage(message: _message!, isError: _error)],
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF414A51), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'),
          )),
        ])),
      ),
    ),
  );
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.message, required this.isError});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: isError ? const Color(0xFFFFF1F0) : const Color(0xFFF2F5F6), borderRadius: BorderRadius.circular(10)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(isError ? Icons.error_outline : Icons.info_outline, size: 20, color: isError ? const Color(0xFFB42318) : const Color(0xFF414A51)),
      const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(height: 1.4))),
    ]),
  );
}
