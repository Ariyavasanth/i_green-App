import 'package:flutter/material.dart';

class LoginIllustrationWidget extends StatelessWidget {
  const LoginIllustrationWidget({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF4F6F7),
    padding: const EdgeInsets.all(48),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 220, height: 220,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, size: 104, color: Color(0xFF414A51)),
          ),
          const SizedBox(height: 40),
          Text('A simpler, safer sign in', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF22282D))),
          const SizedBox(height: 14),
          Text('No passwords to remember. We send a secure one-time code directly to your email.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55, color: const Color(0xFF69737A))),
          const SizedBox(height: 32),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [_Dot(active: true), _Dot(), _Dot()]),
        ]),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({this.active = false});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    width: active ? 24 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(color: active ? const Color(0xFF414A51) : const Color(0xFFCCD1D5), borderRadius: BorderRadius.circular(4)),
  );
}
