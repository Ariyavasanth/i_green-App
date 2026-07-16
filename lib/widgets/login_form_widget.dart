import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/authentication_providers.dart';
import 'custom_text_field.dart';
import 'social_login_button.dart';

class LoginFormWidget extends ConsumerStatefulWidget {
  const LoginFormWidget({super.key});
  @override
  ConsumerState<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends ConsumerState<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  Timer? _timer;
  bool _otpSent = false, _loading = false, _error = false;
  int _resendSeconds = 0;
  String? _message;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  String? _otpValidator(String? value) {
    if (_otpSent && !RegExp(r'^\d{6}$').hasMatch(value ?? '')) return 'Enter the 6-digit code';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final repository = ref.read(authenticationRepositoryProvider);
    try {
      if (!_otpSent) {
        await repository.requestOtp(_email.text.trim());
        if (!mounted) return;
        setState(() { _otpSent = true; _error = false; _message = 'We sent a 6-digit verification code to your email.'; });
        _startTimer();
      } else {
        final valid = await repository.verifyOtp(email: _email.text.trim(), otp: _otp.text);
        if (!mounted) return;
        if (valid) {
          context.go('/home');
        } else {
          setState(() { _error = true; _message = 'That code could not be verified. Please try again.'; });
        }
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _message = 'Something went wrong. Please try again.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authenticationRepositoryProvider).requestOtp(_email.text.trim());
      if (!mounted) return;
      setState(() { _error = false; _message = 'A new verification code has been sent.'; });
      _startTimer();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() { _otpSent = false; _otp.clear(); _message = null; _resendSeconds = 0; });
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final valid = await ref.read(authenticationRepositoryProvider).signInWithGoogle();
      if (valid && mounted) context.go('/home');
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
          Text(_otpSent ? 'Check your email' : 'Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF22282D))),
          const SizedBox(height: 10),
          Text(_otpSent ? 'Enter the verification code sent to ${_email.text.trim()}.' : 'Sign in securely with a one-time verification code.', style: const TextStyle(color: Color(0xFF69737A), height: 1.5)),
          const SizedBox(height: 32),
          if (!_otpSent)
            CustomTextField(controller: _email, label: 'Email address', hint: 'you@example.com', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined, validator: _emailValidator)
          else ...[
            Row(children: [Expanded(child: Text(_email.text.trim(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))), TextButton(onPressed: _changeEmail, child: const Text('Change'))]),
            const SizedBox(height: 14),
            CustomTextField(controller: _otp, label: 'Verification code', hint: 'Enter 6-digit code', keyboardType: TextInputType.number, prefixIcon: Icons.password_outlined, maxLength: 6, validator: _otpValidator),
          ],
          if (_message != null) ...[const SizedBox(height: 18), _InfoMessage(message: _message!, isError: _error)],
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF414A51), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_otpSent ? 'Verify and sign in' : 'Send verification code'),
          )),
          if (_otpSent) ...[
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: _resendSeconds == 0 ? _resend : null, child: Text(_resendSeconds == 0 ? 'Resend OTP' : 'Resend OTP in ${_resendSeconds}s'))),
          ] else ...[
            const SizedBox(height: 24),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: TextStyle(color: Color(0xFF69737A)))), Expanded(child: Divider())]),
            const SizedBox(height: 24),
            SocialLoginButton(onPressed: _googleSignIn, isLoading: _loading),
          ],
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
